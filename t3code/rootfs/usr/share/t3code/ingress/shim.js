// Runs before the T3 Code client boots when served through Home Assistant Ingress
// (injected into index.html by the add-on's nginx, see /etc/nginx/nginx.conf).
// The client assumes it lives at "/", so every same-origin URL it builds is
// re-rooted under the ingress prefix. The browser URL keeps the prefix, so
// reloads and deep links resolve through Home Assistant again.
//
// A new T3 Code release can break this. tests/ingress-e2e.sh is the guard.
(function () {
  "use strict";
  var P = window.__T3_INGRESS_PATH__;
  if (!P || window.__T3_INGRESS_SHIM__) return;
  window.__T3_INGRESS_SHIM__ = true;

  function fix(input, wsScheme) {
    if (input == null) return input;
    var s = String(input);
    if (/^(data|blob|about|javascript|mailto):/i.test(s)) return input;
    var u;
    try { u = new URL(s, location.href); } catch (e) { return input; }
    var httpOrigin = location.protocol + "//" + location.host;
    var wsOrigin = (location.protocol === "https:" ? "wss:" : "ws:") + "//" + location.host;
    var origin = u.protocol + "//" + u.host;
    if (origin !== httpOrigin && origin !== wsOrigin) return input;
    if (u.pathname === P || u.pathname.indexOf(P + "/") === 0) return u.href;
    u.pathname = P + u.pathname;
    if (wsScheme) u.protocol = location.protocol === "https:" ? "wss:" : "ws:";
    return u.href;
  }
  window.__T3_INGRESS_FIX__ = fix;

  // Home Assistant already authenticated the user, so sign in automatically: the
  // add-on mints a one-time pairing credential at /_ingress/pair (404 when the
  // ingress_auto_login option is off) and it is exchanged for a browser session
  // before the app starts. Synchronous on purpose: the app must not boot signed out.
  function syncJson(method, url, body) {
    var x = new XMLHttpRequest();
    x.open(method, P + url, false);
    x.withCredentials = true;
    if (body) x.setRequestHeader("content-type", "application/json");
    x.send(body ? JSON.stringify(body) : null);
    if (x.status < 200 || x.status >= 300) return null;
    try { return JSON.parse(x.responseText); } catch (e) { return null; }
  }
  try {
    var session = syncJson("GET", "/api/auth/session");
    if (session && session.authenticated === false) {
      var minted = syncJson("POST", "/_ingress/pair", {});
      if (minted && minted.credential) {
        syncJson("POST", "/api/auth/browser-session", { credential: minted.credential });
      }
    }
  } catch (e) { console.warn("[t3-ingress] auto sign-in failed", e); }

  var origFetch = window.fetch;
  window.fetch = function (input, init) {
    if (input instanceof Request) {
      var fixed = fix(input.url);
      if (fixed !== input.url) input = new Request(fixed, input);
    } else {
      input = fix(input);
    }
    return origFetch.call(this, input, init);
  };

  var origOpen = XMLHttpRequest.prototype.open;
  XMLHttpRequest.prototype.open = function (method, url) {
    var args = Array.prototype.slice.call(arguments);
    args[1] = fix(url);
    return origOpen.apply(this, args);
  };

  function wrapCtor(name, ws) {
    var Orig = window[name];
    if (!Orig) return;
    var Wrapped = function (url, opts) {
      return arguments.length > 1 ? new Orig(fix(url, ws), opts) : new Orig(fix(url, ws));
    };
    Wrapped.prototype = Orig.prototype;
    Object.getOwnPropertyNames(Orig).forEach(function (k) {
      if (!(k in Wrapped)) { try { Wrapped[k] = Orig[k]; } catch (e) {} }
    });
    window[name] = Wrapped;
  }
  wrapCtor("WebSocket", true);
  wrapCtor("EventSource", false);
  wrapCtor("Worker", false);
  wrapCtor("SharedWorker", false);

  if (navigator.sendBeacon) {
    var origBeacon = navigator.sendBeacon.bind(navigator);
    navigator.sendBeacon = function (url, data) { return origBeacon(fix(url), data); };
  }

  // A service worker registered here would sit on the Home Assistant origin.
  if (navigator.serviceWorker && navigator.serviceWorker.register) {
    navigator.serviceWorker.register = function () {
      return Promise.reject(new Error("service workers are disabled under Home Assistant Ingress"));
    };
  }

  function patchUrlProp(proto, prop) {
    var d = Object.getOwnPropertyDescriptor(proto, prop);
    if (!d || !d.set) return;
    Object.defineProperty(proto, prop, {
      configurable: true, enumerable: d.enumerable, get: d.get,
      set: function (v) { d.set.call(this, fix(v)); }
    });
  }
  patchUrlProp(HTMLLinkElement.prototype, "href");
  patchUrlProp(HTMLScriptElement.prototype, "src");
  patchUrlProp(HTMLImageElement.prototype, "src");
  patchUrlProp(HTMLSourceElement.prototype, "src");
  patchUrlProp(HTMLIFrameElement.prototype, "src");

  var origSetAttr = Element.prototype.setAttribute;
  Element.prototype.setAttribute = function (name, value) {
    var n = String(name).toLowerCase();
    if ((n === "src" || n === "href") && !(this instanceof SVGElement)) value = fix(value);
    return origSetAttr.call(this, name, value);
  };

  // TanStack Router reads `options.basepath ?? "/"`. The client never sets it,
  // so a non-enumerable fallback on Object.prototype supplies the ingress prefix
  // and the real URL keeps it: reloads and deep links keep working.
  Object.defineProperty(Object.prototype, "basepath", {
    configurable: true, enumerable: false,
    // Only plain option objects get the fallback; the router instance itself must
    // start without one so it notices the change and installs its rewrite.
    get: function () { return Object.getPrototypeOf(this) === Object.prototype ? P : undefined; },
    set: function (v) {
      Object.defineProperty(this, "basepath", { value: v, writable: true, enumerable: true, configurable: true });
    }
  });
})();
