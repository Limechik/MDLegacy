#import "MDHttp.h"
#import <UIKit/UIKit.h>
#include <signal.h>
#include <pthread.h>
#include "mbedtls/net_sockets.h"
#include "mbedtls/ssl.h"
#include "mbedtls/entropy.h"
#include "mbedtls/ctr_drbg.h"
#include "mbedtls/x509_crt.h"
#include "mbedtls/error.h"
#include "mbedtls/debug.h"
#include "psa/crypto.h"
#include "mbedtls/platform_time.h"
#include <mach/mach_time.h>
#include <dlfcn.h>
#include <fcntl.h>
#include <unistd.h>

// iOS 6 SDK has no clock_gettime/CLOCK_MONOTONIC → built with -DMBEDTLS_PLATFORM_MS_TIME_ALT
mbedtls_ms_time_t mbedtls_ms_time(void) {
    static mach_timebase_info_data_t tb;
    if (tb.denom == 0) mach_timebase_info(&tb);
    uint64_t ns = mach_absolute_time() * tb.numer / tb.denom;
    return (mbedtls_ms_time_t)(ns / 1000000ULL);
}

@implementation MDHttpResponse
- (BOOL)isSuccessful { return !_error && _statusCode >= 200 && _statusCode < 300; }
@end

// ---------------------------------------------------------------------------
// Pure-C TLS 1.3/1.2 exchange (mbedTLS 3.6): send `req`, read until the server closes (Connection: close).
// Certificates are verified against the PEM bundle (Resources/roots.pem).
// ---------------------------------------------------------------------------
// Collect the interesting debug lines (alert type, chosen ciphersuite, versions) into ctx
static void md_dbg(void *ctx, int level, const char *file, int line, const char *str) {
    char *buf = (char *)ctx; size_t n = strlen(buf);
    if (n > 380) return;
    if (strstr(str, "alert") || strstr(str, "ciphersuite") || strstr(str, "version") || strstr(str, "curve")) {
        const char *q = strrchr(str, ':') ? str : str; (void)q; (void)file; (void)line; (void)level;
        snprintf(buf + n, 500 - n, "%.*s; ", (int)strcspn(str, "\r\n"), str);
    }
}

// A long-lived process can keep a stale DNS configuration after Wi-Fi sleep / network change
// (getaddrinfo then fails with UNKNOWN_HOST although the device is online). res_init() reloads it.
// Looked up via dlsym so the build needs no extra -l flag.
static void md_reset_resolver(void) {
    int (*ri)(void) = (int (*)(void))dlsym(RTLD_DEFAULT, "res_init");
    if (ri) ri();
}
// Diagnostic: number of open file descriptors (a leak would show up here as a huge number)
static int md_open_fds(void) {
    int n = 0; for (int i = 0; i < 1024; i++) if (fcntl(i, F_GETFD) != -1) n++;
    return n;
}

// Parsed once and shared (read-only afterwards) — parsing the whole bundle per request is far too slow on armv7
static mbedtls_x509_crt gCA; static int gCAReady = 0; static pthread_mutex_t gCAMutex = PTHREAD_MUTEX_INITIALIZER;

static int md_tls_exchange(const char *host, const char *port,
                           const unsigned char *pem, size_t pemlen,
                           const unsigned char *req, size_t reqlen,
                           CFMutableDataRef out, char *err, size_t errlen, int *endRet)
{
    mbedtls_net_context net; mbedtls_ssl_context ssl; mbedtls_ssl_config conf;
    mbedtls_entropy_context ent; mbedtls_ctr_drbg_context drbg;
    int ret = 0, rc = -1; const char *what = "init"; char eb[160];
    unsigned char rb[8192]; size_t sent = 0; char dbg[500]; dbg[0] = 0;

    mbedtls_net_init(&net); mbedtls_ssl_init(&ssl); mbedtls_ssl_config_init(&conf);
    mbedtls_entropy_init(&ent); mbedtls_ctr_drbg_init(&drbg);

    what = "psa";
    { static int psa_done = 0; static pthread_mutex_t m = PTHREAD_MUTEX_INITIALIZER;
      pthread_mutex_lock(&m);
      if (!psa_done && psa_crypto_init() == PSA_SUCCESS) psa_done = 1;
      pthread_mutex_unlock(&m);
      if (!psa_done) { ret = MBEDTLS_ERR_SSL_INTERNAL_ERROR; goto fail; } }
    what = "rng";
    if ((ret = mbedtls_ctr_drbg_seed(&drbg, mbedtls_entropy_func, &ent, (const unsigned char *)"mdlegacy", 8)) != 0) goto fail;
    what = "roots.pem";
    pthread_mutex_lock(&gCAMutex);
    if (!gCAReady) {
        mbedtls_x509_crt_init(&gCA);
        ret = mbedtls_x509_crt_parse(&gCA, pem, pemlen);                        // >0 = some certs skipped, fine
        if (ret >= 0) { gCAReady = 1; ret = 0; } else mbedtls_x509_crt_free(&gCA);
    }
    pthread_mutex_unlock(&gCAMutex);
    if (!gCAReady) goto fail;
    what = "config";
    if ((ret = mbedtls_ssl_config_defaults(&conf, MBEDTLS_SSL_IS_CLIENT, MBEDTLS_SSL_TRANSPORT_STREAM,
                                           MBEDTLS_SSL_PRESET_DEFAULT)) != 0) goto fail;
    mbedtls_ssl_conf_authmode(&conf, MBEDTLS_SSL_VERIFY_REQUIRED);
    mbedtls_ssl_conf_ca_chain(&conf, &gCA, NULL);
    mbedtls_ssl_conf_rng(&conf, mbedtls_ctr_drbg_random, &drbg);
    mbedtls_ssl_conf_read_timeout(&conf, 30000);
    mbedtls_debug_set_threshold(2);
    mbedtls_ssl_conf_dbg(&conf, md_dbg, dbg);
    what = "setup";
    if ((ret = mbedtls_ssl_setup(&ssl, &conf)) != 0) goto fail;
    if ((ret = mbedtls_ssl_set_hostname(&ssl, host)) != 0) goto fail;             // SNI + name check
    what = "connect";
    for (int attempt = 0; ; attempt++) {
        ret = mbedtls_net_connect(&net, host, port, MBEDTLS_NET_PROTO_TCP);
        if (ret == 0) break;
        if (attempt >= 2 || (ret != MBEDTLS_ERR_NET_UNKNOWN_HOST && ret != MBEDTLS_ERR_NET_CONNECT_FAILED)) goto fail;
        md_reset_resolver();                                   // stale DNS state → reload and try again
        mbedtls_net_free(&net); mbedtls_net_init(&net);
        usleep(400000 * (attempt + 1));
    }
    mbedtls_ssl_set_bio(&ssl, &net, mbedtls_net_send, NULL, mbedtls_net_recv_timeout);

    what = "handshake";
    while ((ret = mbedtls_ssl_handshake(&ssl)) != 0)
        if (ret != MBEDTLS_ERR_SSL_WANT_READ && ret != MBEDTLS_ERR_SSL_WANT_WRITE &&
            ret != MBEDTLS_ERR_SSL_RECEIVED_NEW_SESSION_TICKET) goto fail;

    what = "write";
    while (sent < reqlen) {
        ret = mbedtls_ssl_write(&ssl, req + sent, reqlen - sent);
        if (ret == MBEDTLS_ERR_SSL_WANT_READ || ret == MBEDTLS_ERR_SSL_WANT_WRITE) continue;
        if (ret == MBEDTLS_ERR_SSL_RECEIVED_NEW_SESSION_TICKET) continue;
        if (ret < 0) goto fail;
        sent += (size_t)ret;
    }
    what = "read";
    for (;;) {
        ret = mbedtls_ssl_read(&ssl, rb, sizeof rb);
        if (ret == MBEDTLS_ERR_SSL_WANT_READ || ret == MBEDTLS_ERR_SSL_WANT_WRITE) continue;
        if (ret == MBEDTLS_ERR_SSL_RECEIVED_NEW_SESSION_TICKET) continue;     // TLS 1.3 post-handshake ticket
        if (ret == 0 || ret == MBEDTLS_ERR_SSL_PEER_CLOSE_NOTIFY) { *endRet = ret; break; }
        if (ret < 0) { if (CFDataGetLength(out) > 0) { *endRet = ret; break; } goto fail; }      // truncated close: caller validates length
        CFDataAppendBytes(out, rb, ret);
    }
    mbedtls_ssl_close_notify(&ssl);
    rc = 0; goto done;

fail:
    mbedtls_strerror(ret, eb, sizeof eb);
    snprintf(err, errlen, "TLS %s: %s (-0x%04X)", what, eb, (unsigned)-ret);
    if (strcmp(what, "connect") == 0) { size_t n = strlen(err); snprintf(err + n, errlen - n, " [fds=%d]", md_open_fds()); }
    if (ret == MBEDTLS_ERR_X509_CERT_VERIFY_FAILED) {
        char vb[200]; mbedtls_x509_crt_verify_info(vb, sizeof vb, " ", mbedtls_ssl_get_verify_result(&ssl));
        size_t n = strlen(err); snprintf(err + n, errlen - n, " |%s", vb);
    }
    if (dbg[0]) { size_t n = strlen(err); snprintf(err + n, errlen - n, " {%s}", dbg); }
done:
    mbedtls_net_free(&net); mbedtls_ssl_free(&ssl); mbedtls_ssl_config_free(&conf);
    mbedtls_ctr_drbg_free(&drbg); mbedtls_entropy_free(&ent);
    return rc;
}

// ---------------------------------------------------------------------------
static MDHttpResponse *MDFail(NSString *msg) {
    MDHttpResponse *r = [MDHttpResponse new];
    r.error = [NSError errorWithDomain:@"ru.local.mangadex.http" code:-1 userInfo:@{NSLocalizedDescriptionKey: msg}];
    return r;
}

static NSData *MDRootsPem(void) {
    static NSData *pem; static dispatch_once_t once;
    dispatch_once(&once, ^{
        signal(SIGPIPE, SIG_IGN);
        NSString *p = [[NSBundle mainBundle] pathForResource:@"roots" ofType:@"pem"];
        NSData *d = p ? [NSData dataWithContentsOfFile:p] : nil;
        if (d.length) { NSMutableData *m = [d mutableCopy]; uint8_t z = 0; [m appendBytes:&z length:1]; pem = m; }  // mbedTLS wants NUL for PEM
    });
    return pem;
}

// "Transfer-Encoding: chunked" → plain body; nil if truncated
static NSData *MDDechunk(NSData *raw) {
    NSMutableData *out = [NSMutableData data];
    const uint8_t *b = raw.bytes; NSUInteger n = raw.length, i = 0;
    while (i < n) {
        NSUInteger j = i; while (j + 1 < n && !(b[j] == '\r' && b[j + 1] == '\n')) j++;
        if (j + 1 >= n) return nil;
        char tmp[24]; NSUInteger l = MIN(j - i, sizeof(tmp) - 1); memcpy(tmp, b + i, l); tmp[l] = 0;
        unsigned long sz = strtoul(tmp, NULL, 16);
        i = j + 2;
        if (sz == 0) return out;
        if (i + sz > n) return nil;
        [out appendBytes:b + i length:sz]; i += sz + 2;
    }
    return nil;
}

static MDHttpResponse *MDDoGet(NSString *url, int depth) {
    if (![url hasPrefix:@"https://"]) return MDFail(@"Поддерживается только https");
    NSString *rest = [url substringFromIndex:8], *hostport = rest, *path = @"/";
    NSRange sl = [rest rangeOfString:@"/"];
    if (sl.location != NSNotFound) { hostport = [rest substringToIndex:sl.location]; path = [rest substringFromIndex:sl.location]; }
    NSString *host = hostport, *port = @"443";
    NSRange c = [hostport rangeOfString:@":"];
    if (c.location != NSNotFound) { host = [hostport substringToIndex:c.location]; port = [hostport substringFromIndex:c.location + 1]; }

    NSData *pem = MDRootsPem();
    if (!pem) return MDFail(@"Нет Resources/roots.pem");

    NSString *reqStr = [NSString stringWithFormat:
        @"GET %@ HTTP/1.1\r\nHost: %@\r\nUser-Agent: %@\r\nAccept: */*\r\nConnection: close\r\n\r\n",
        path, hostport, [MDHttp userAgent]];
    NSData *req = [reqStr dataUsingEncoding:NSUTF8StringEncoding];

    CFMutableDataRef out = CFDataCreateMutable(NULL, 0); char err[900] = {0}; int endRet = 0;
    int rc = md_tls_exchange(host.UTF8String, port.UTF8String, pem.bytes, pem.length, req.bytes, req.length, out, err, sizeof err, &endRet);
    NSData *raw = CFBridgingRelease(out);
    if (rc != 0) { NSLog(@"MDHttp %@ → %s", url, err); return MDFail([NSString stringWithUTF8String:err]); }

    NSData *sep = [@"\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding];
    NSRange hr = [raw rangeOfData:sep options:0 range:NSMakeRange(0, raw.length)];
    if (hr.location == NSNotFound) return MDFail(@"Неполный ответ сервера");
    NSString *head = [[NSString alloc] initWithData:[raw subdataWithRange:NSMakeRange(0, hr.location)] encoding:NSUTF8StringEncoding]
                  ?: [[NSString alloc] initWithData:[raw subdataWithRange:NSMakeRange(0, hr.location)] encoding:NSISOLatin1StringEncoding];
    NSArray *lines = [head componentsSeparatedByString:@"\r\n"];
    NSArray *st = [lines[0] componentsSeparatedByString:@" "];
    if (st.count < 2) return MDFail(@"Неверный ответ сервера");
    NSMutableDictionary *h = [NSMutableDictionary dictionary];
    for (NSUInteger i = 1; i < lines.count; i++) {
        NSRange k = [lines[i] rangeOfString:@":"]; if (k.location == NSNotFound) continue;
        h[[[lines[i] substringToIndex:k.location] lowercaseString]] =
            [[lines[i] substringFromIndex:k.location + 1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    }
    NSInteger code = [st[1] integerValue];

    if ((code == 301 || code == 302 || code == 303 || code == 307 || code == 308) && h[@"location"] && depth < 5) {
        NSString *loc = h[@"location"];
        if ([loc hasPrefix:@"/"]) loc = [NSString stringWithFormat:@"https://%@%@", hostport, loc];
        return MDDoGet(loc, depth + 1);
    }

    NSData *body = [raw subdataWithRange:NSMakeRange(NSMaxRange(hr), raw.length - NSMaxRange(hr))];
    NSString *te = [h[@"transfer-encoding"] lowercaseString];     // nil-safe: messaging nil would give location 0, not NSNotFound
    if (te.length && [te rangeOfString:@"chunked"].location != NSNotFound) {
        body = MDDechunk(body); if (!body) return MDFail(@"Обрыв передачи данных");
    } else if (h[@"content-length"] && (NSInteger)body.length < [h[@"content-length"] integerValue]) {
        return MDFail(@"Обрыв передачи данных");
    }
    MDHttpResponse *r = [MDHttpResponse new];
    r.statusCode = code; r.headers = h; r.body = body; r.endCode = endRet;
    return r;
}

// ---------------------------------------------------------------------------
@interface MDCacheEntry : NSObject
@property (nonatomic, strong) MDHttpResponse *response; @property (nonatomic) NSTimeInterval storedAt;
@end
@implementation MDCacheEntry @end

@implementation MDHttp
static NSMutableDictionary *gCache;

+ (NSString *)userAgent {
    return [NSString stringWithFormat:@"MDLegacy/1.0 (iOS %@; +com.lime.mdlegacy)",
            [[UIDevice currentDevice] systemVersion]];
}

+ (MDHttpResponse *)get:(NSString *)url cacheForTTL:(NSTimeInterval)ttl {
    NSTimeInterval now = CFAbsoluteTimeGetCurrent();
    if (ttl > 0) @synchronized (self) {
        MDCacheEntry *e = gCache[url];
        if (e && now - e.storedAt < ttl) return e.response;
    }
    MDHttpResponse *r = MDDoGet(url, 0);
    if (ttl > 0 && r.isSuccessful) @synchronized (self) {
        if (!gCache) gCache = [NSMutableDictionary dictionary];
        MDCacheEntry *e = [MDCacheEntry new]; e.response = r; e.storedAt = now; gCache[url] = e;
    }
    return r;
}
+ (void)dropMemoryCache { @synchronized (self) { [gCache removeAllObjects]; } }
@end
