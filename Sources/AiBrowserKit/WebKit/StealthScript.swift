import Foundation

/// JavaScript injected at document-start into every frame to make WKWebView
/// indistinguishable from real Safari to bot-detection systems.
///
/// Injections run before any page script executes, so properties are set
/// before any fingerprinting library can read them.
enum StealthScript {

    // MARK: - Public entry point

    /// The complete stealth script. Inject via WKUserScript at .atDocumentStart
    /// with forMainFrameOnly: false so iframes are also covered.
    static let source: String = [
        removeWebdriver,
        addSafariObject,
        cleanWebkitHandlers,
        spoofPlugins,
        spoofPermissions,
        fixNavigatorProperties,
        addCanvasNoise,
        spoofWebGL,
        hideAutomationCues,
    ].joined(separator: "\n\n")

    // MARK: - Individual patches

    /// Remove navigator.webdriver — the single most checked bot signal.
    private static let removeWebdriver = """
    (function() {
        try {
            Object.defineProperty(navigator, 'webdriver', {
                get: () => undefined,
                configurable: true
            });
        } catch(_) {}
    })();
    """

    /// Add window.safari — present in real Safari, absent in WKWebView.
    /// Many fingerprinters check `typeof window.safari.pushNotification`.
    private static let addSafariObject = """
    (function() {
        if (window.safari) return;
        try {
            function SafariRemoteNotification() {}
            SafariRemoteNotification.prototype.toString = function() {
                return '[object SafariRemoteNotification]';
            };
            SafariRemoteNotification.prototype.permission = function(bundleIdentifier) {
                return { deviceToken: null, permission: 'default' };
            };
            SafariRemoteNotification.prototype.requestPermission = function(
                bundleIdentifier, webServiceURL, userInfo, completionHandler
            ) {
                completionHandler({ deviceToken: null, permission: 'denied' });
            };
            Object.defineProperty(window, 'safari', {
                value: { pushNotification: new SafariRemoteNotification() },
                enumerable: false,
                configurable: false,
                writable: false
            });
        } catch(_) {}
    })();
    """

    /// Remove custom WKWebView message handlers from window.webkit.
    /// Real Safari exposes window.webkit but has no custom messageHandlers.
    /// Our console handler captures its reference via closure before this runs,
    /// so removing the window-level property does not break console interception.
    private static let cleanWebkitHandlers = """
    (function() {
        try {
            var mh = window.webkit && window.webkit.messageHandlers;
            if (!mh) return;
            Object.getOwnPropertyNames(mh).forEach(function(key) {
                try { delete mh[key]; } catch(_) {}
            });
        } catch(_) {}
    })();
    """

    /// Spoof navigator.plugins with realistic Safari entries.
    /// WKWebView returns an empty PluginArray; real Safari has PDF plugins.
    private static let spoofPlugins = """
    (function() {
        try {
            var fakePlugin = function(name, desc, filename, mimeTypes) {
                return Object.create(Plugin.prototype, {
                    name:        { value: name,     enumerable: true },
                    description: { value: desc,     enumerable: true },
                    filename:    { value: filename, enumerable: true },
                    length:      { value: mimeTypes.length, enumerable: true }
                });
            };
            var pdfPlugin = fakePlugin(
                'PDF Viewer',
                'Portable Document Format',
                'internal-pdf-viewer',
                ['application/pdf', 'text/pdf']
            );
            Object.defineProperty(navigator, 'plugins', {
                get: function() { return [pdfPlugin]; },
                configurable: true
            });
            Object.defineProperty(navigator, 'mimeTypes', {
                get: function() {
                    return [
                        { type: 'application/pdf', suffixes: 'pdf', description: 'Portable Document Format', enabledPlugin: pdfPlugin },
                        { type: 'text/pdf',        suffixes: 'pdf', description: 'Portable Document Format', enabledPlugin: pdfPlugin }
                    ];
                },
                configurable: true
            });
        } catch(_) {}
    })();
    """

    /// Override Notification.permission and other Web API permission queries
    /// to return realistic values rather than WKWebView's restrictive defaults.
    private static let spoofPermissions = """
    (function() {
        if (!navigator.permissions) return;
        var orig = navigator.permissions.query.bind(navigator.permissions);
        navigator.permissions.query = function(parameters) {
            if (parameters.name === 'notifications') {
                return Promise.resolve({ state: 'prompt', onchange: null });
            }
            return orig(parameters);
        };
    })();
    """

    /// Ensure navigator properties match a real Safari session on macOS.
    private static let fixNavigatorProperties = """
    (function() {
        var overrides = {
            appName:     'Netscape',
            appCodeName: 'Mozilla',
            product:     'Gecko',
            productSub:  '20030107',
            vendor:      'Apple Computer, Inc.',
            vendorSub:   ''
        };
        Object.keys(overrides).forEach(function(key) {
            try {
                if (navigator[key] !== overrides[key]) {
                    Object.defineProperty(navigator, key, {
                        get: function() { return overrides[key]; },
                        configurable: true
                    });
                }
            } catch(_) {}
        });
    })();
    """

    /// Add subtle per-session noise to canvas readback.
    /// Canvas fingerprinting works by reading exact pixel values from a drawn image.
    /// A consistent ±1 RGB shift defeats fingerprint matching across sessions
    /// while remaining invisible to the human eye.
    private static let addCanvasNoise = """
    (function() {
        var shift = (Math.random() < 0.5 ? 1 : -1);
        var proto  = HTMLCanvasElement.prototype;
        var origToDataURL = proto.toDataURL;
        var origGetImageData = CanvasRenderingContext2D.prototype.getImageData;

        proto.toDataURL = function(type, quality) {
            var ctx = this.getContext('2d');
            if (ctx) {
                var imageData = origGetImageData.call(ctx, 0, 0, this.width, this.height);
                for (var i = 0; i < imageData.data.length; i += 4) {
                    imageData.data[i]     = Math.min(255, Math.max(0, imageData.data[i]     + shift));
                    imageData.data[i + 1] = Math.min(255, Math.max(0, imageData.data[i + 1] + shift));
                }
                ctx.putImageData(imageData, 0, 0);
            }
            return origToDataURL.apply(this, arguments);
        };

        CanvasRenderingContext2D.prototype.getImageData = function(sx, sy, sw, sh) {
            var imageData = origGetImageData.call(this, sx, sy, sw, sh);
            for (var i = 0; i < imageData.data.length; i += 4) {
                imageData.data[i]     = Math.min(255, Math.max(0, imageData.data[i]     + shift));
                imageData.data[i + 1] = Math.min(255, Math.max(0, imageData.data[i + 1] + shift));
            }
            return imageData;
        };
    })();
    """

    /// Spoof WebGL renderer strings so the GPU isn't exposed.
    /// Bots/fingerprinters query UNMASKED_VENDOR_WEBGL and UNMASKED_RENDERER_WEBGL.
    private static let spoofWebGL = """
    (function() {
        var getParam = WebGLRenderingContext.prototype.getParameter;
        WebGLRenderingContext.prototype.getParameter = function(parameter) {
            if (parameter === 37445) return 'Apple Inc.';   // UNMASKED_VENDOR_WEBGL
            if (parameter === 37446) return 'Apple GPU';    // UNMASKED_RENDERER_WEBGL
            return getParam.call(this, parameter);
        };
        if (window.WebGL2RenderingContext) {
            var getParam2 = WebGL2RenderingContext.prototype.getParameter;
            WebGL2RenderingContext.prototype.getParameter = function(parameter) {
                if (parameter === 37445) return 'Apple Inc.';
                if (parameter === 37446) return 'Apple GPU';
                return getParam2.call(this, parameter);
            };
        }
    })();
    """

    /// Hide common automation / headless browser cues.
    private static let hideAutomationCues = """
    (function() {
        try { delete window.$cdc_asdjflasutopfhvcZLmcfl_; } catch(_) {}
        try { delete window.$wdc_; } catch(_) {}

        Object.defineProperty(document, 'hasFocus', {
            value: function() { return true; },
            configurable: true
        });
    })();
    """
}
