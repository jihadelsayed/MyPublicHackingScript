ory that allows easy instantiation of configurable focus traps. */\nclass ConfigurableFocusTrapFactory {\n    constructor(_checker, _ngZone, _focusTrapManager, _document, _inertStrategy) {\n        this._checker = _checker;\n        this._ngZone = _ngZone;\n        this._focusTrapManager = _focusTrapManager;\n        this._document = _document;\n        // TODO split up the strategies into different modules, similar to DateAdapter.\n        this._inertStrategy = _inertStrategy || new EventListenerFocusTrapInertStrategy();\n    }\n    create(element, config = { defer: false }) {\n        let configObject;\n        if (typeof config === 'boolean') {\n            configObject = { defer: config };\n        }\n        else {\n            configObject = config;\n        }\n        return new ConfigurableFocusTrap(element, this._checker, this._ngZone, this._document, this._focusTrapManager, this._inertStrategy, configObject);\n    }\n}\nConfigurableFocusTrapFactory.Éµfac = i0.ÉµÉµngDeclareFactory({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: ConfigurableFocusTrapFactory, deps: [{ token: InteractivityChecker }, { token: i0.NgZone }, { token: FocusTrapManager }, { token: DOCUMENT }, { token: FOCUS_TRAP_INERT_STRATEGY, optional: true }], target: i0.ÉµÉµFactoryTarget.Injectable });\nConfigurableFocusTrapFactory.Éµprov = i0.ÉµÉµngDeclareInjectable({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: ConfigurableFocusTrapFactory, providedIn: 'root' });\ni0.ÉµÉµngDeclareClassMetadata({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: ConfigurableFocusTrapFactory, decorators: [{\n            type: Injectable,\n            args: [{ providedIn: 'root' }]\n        }], ctorParameters: function () { return [{ type: InteractivityChecker }, { type: i0.NgZone }, { type: FocusTrapManager }, { type: undefined, decorators: [{\n                    type: Inject,\n                    args: [DOCUMENT]\n                }] }, { type: undefined, decorators: [{\n                    type: Optional\n                }, {\n                    type: Inject,\n                    args: [FOCUS_TRAP_INERT_STRATEGY]\n                }] }]; } });\n\n/**\n * @license\n * Copyright Google LLC All Rights Reserved.\n *\n * Use of this source code is governed by an MIT-style license that can be\n * found in the LICENSE file at https://angular.io/license\n */\n/** Gets whether an event could be a faked `mousedown` event dispatched by a screen reader. */\nfunction isFakeMousedownFromScreenReader(event) {\n    // Some screen readers will dispatch a fake `mousedown` event when pressing enter or space on\n    // a clickable element. We can distinguish these events when both `offsetX` and `offsetY` are\n    // zero. Note that there's an edge case where the user could click the 0x0 spot of the screen\n    // themselves, but that is unlikely to contain interaction elements. Historically we used to\n    // check `event.buttons === 0`, however that no longer works on recent versions of NVDA.\n    return event.offsetX === 0 && event.offsetY === 0;\n}\n/** Gets whether an event could be a faked `touchstart` event dispatched by a screen reader. */\nfunction isFakeTouchstartFromScreenReader(event) {\n    const touch = (event.touches && event.touches[0]) || (event.changedTouches && event.changedTouches[0]);\n    // A fake `touchstart` can be distinguished from a real one by looking at the `identifier`\n    // which is typically >= 0 on a real device versus -1 from a screen reader. Just to be safe,\n    // we can also look at `radiusX` and `radiusY`. This behavior was observed against a Windows 10\n    // device with a touch screen running NVDA v2020.4 and Firefox 85 or Chrome 88.\n    return (!!touch &&\n        touch.identifier === -1 &&\n        (touch.radiusX == null || touch.radiusX === 1) &&\n        (touch.radiusY == null || touch.radiusY === 1));\n}\n\n/**\n * @license\n * Copyright Google LLC All Rights Reserved.\n *\n * Use of this source code is governed by an MIT-style license that can be\n * found in the LICENSE file at https://angular.io/license\n */\n/**\n * Injectable options for the InputModalityDetector. These are shallowly merged with the default\n * options.\n */\nconst INPUT_MODALITY_DETECTOR_OPTIONS = new InjectionToken('cdk-input-modality-detector-options');\n/**\n * Default options for the InputModalityDetector.\n *\n * Modifier keys are ignored by default (i.e. when pressed won't cause the service to detect\n * keyboard input modality) for two reasons:\n *\n * 1. Modifier keys are commonly used with mouse to perform actions such as 'right click' or 'open\n *    in new tab', and are thus less representative of actual keyboard interaction.\n * 2. VoiceOver triggers some keyboard events when linearly navigating with Control + Option (but\n *    confusingly not with Caps Lock). Thus, to have parity with other screen readers, we ignore\n *    these keys so as to not update the input modality.\n *\n * Note that we do not by default ignore the right Meta key on Safari because it has the same key\n * code as the ContextMenu key on other browsers. When we switch to using event.key, we can\n * distinguish between the two.\n */\nconst INPUT_MODALITY_DETECTOR_DEFAULT_OPTIONS = {\n    ignoreKeys: [ALT, CONTROL, MAC_META, META, SHIFT],\n};\n/**\n * The amount of time needed to pass after a touchstart event in order for a subsequent mousedown\n * event to be attributed as mouse and not touch.\n *\n * This is the value used by AngularJS Material. Through trial and error (on iPhone 6S) they found\n * that a value of around 650ms seems appropriate.\n */\nconst TOUCH_BUFFER_MS = 650;\n/**\n * Event listener options that enable capturing and also mark the listener as passive if the browser\n * supports it.\n */\nconst modalityEventListenerOptions = normalizePassiveListenerOptions({\n    passive: true,\n    capture: true,\n});\n/**\n * Service that detects the user's input modality.\n *\n * This service does not update the input modality when a user navigates with a screen reader\n * (e.g. linear navigation with VoiceOver, object navigation / browse mode with NVDA, virtual PC\n * cursor mode with JAWS). This is in part due to technical limitations (i.e. keyboard events do not\n * fire as expected in these modes) but is also arguably the correct behavior. Navigating with a\n * screen reader is akin to visually scanning a page, and should not be interpreted as actual user\n * input interaction.\n *\n * When a user is not navigating but *interacting* with a screen reader, this service attempts to\n * update the input modality to keyboard, but in general this service's behavior is largely\n * undefined.\n */\nclass InputModalityDetector {\n    constructor(_platform, ngZone, document, options) {\n        this._platform = _platform;\n        /**\n         * The most recently detected input modality event target. Is null if no input modality has been\n         * detected or if the associated event target is null for some unknown reason.\n         */\n        this._mostRecentTarget = null;\n        /** The underlying BehaviorSubject that emits whenever an input modality is detected. */\n        this._modality = new BehaviorSubject(null);\n        /**\n         * The timestamp of the last touch input modality. Used to determine whether mousedown events\n         * should be attributed to mouse or touch.\n         */\n        this._lastTouchMs = 0;\n        /**\n         * Handles keydown events. Must be an arrow function in order to preserve the context when it gets\n         * bound.\n         */\n        this._onKeydown = (event) => {\n            // If this is one of the keys we should ignore, then ignore it and don't update the input\n            // modality to keyboard.\n            if (this._options?.ignoreKeys?.some(keyCode => keyCode === event.keyCode)) {\n                return;\n            }\n            this._modality.next('keyboard');\n            this._mostRecentTarget = _getEventTarget(event);\n        };\n        /**\n         * Handles mousedown events. Must be an arrow function in order to preserve the context when it\n         * gets bound.\n         */\n        this._onMousedown = (event) => {\n            // Touches trigger both touch and mouse events, so we need to distinguish between mouse events\n            // that were triggered via mouse vs touch. To do so, check if the mouse event occurs closely\n            // after the previous touch event.\n            if (Date.now() - this._lastTouchMs < TOUCH_BUFFER_MS) {\n                return;\n            }\n            // Fake mousedown events are fired by some screen readers when controls are activated by the\n            // screen reader. Attribute them to keyboard input modality.\n            this._modality.next(isFakeMousedownFromScreenReader(event) ? 'keyboard' : 'mouse');\n            this._mostRecentTarget = _getEventTarget(event);\n        };\n        /**\n         * Handles touchstart events. Must be an arrow function in order to preserve the context when it\n         * gets bound.\n         */\n        this._onTouchstart = (event) => {\n            // Same scenario as mentioned in _onMousedown, but on touch screen devices, fake touchstart\n            // events are fired. Again, attribute to keyboard input modality.\n            if (isFakeTouchstartFromScreenReader(event)) {\n                this._modality.next('keyboard');\n                return;\n            }\n            // Store the timestamp of this touch event, as it's used to distinguish between mouse events\n            // triggered via mouse vs touch.\n            this._lastTouchMs = Date.now();\n            this._modality.next('touch');\n            this._mostRecentTarget = _getEventTarget(event);\n        };\n        this._options = {\n            ...INPUT_MODALITY_DETECTOR_DEFAULT_OPTIONS,\n            ...options,\n        };\n        // Skip the first emission as it's null.\n        this.modalityDetected = this._modality.pipe(skip(1));\n        this.modalityChanged = this.modalityDetected.pipe(distinctUntilChanged());\n        // If we're not in a browser, this service should do nothing, as there's no relevant input\n        // modality to detect.\n        if (_platform.isBrowser) {\n            ngZone.runOutsideAngular(() => {\n                document.addEventListener('keydown', this._onKeydown, modalityEventListenerOptions);\n                document.addEventListener('mousedown', this._onMousedown, modalityEventListenerOptions);\n                document.addEventListener('touchstart', this._onTouchstart, modalityEventListenerOptions);\n            });\n        }\n    }\n    /** The most recently detected input modality. */\n    get mostRecentModality() {\n        return this._modality.value;\n    }\n    ngOnDestroy() {\n        this._modality.complete();\n        if (this._platform.isBrowser) {\n            document.removeEventListener('keydown', this._onKeydown, modalityEventListenerOptions);\n            document.removeEventListener('mousedown', this._onMousedown, modalityEventListenerOptions);\n            document.removeEventListener('touchstart', this._onTouchstart, modalityEventListenerOptions);\n        }\n    }\n}\nInputModalityDetector.Éµfac = i0.ÉµÉµngDeclareFactory({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: InputModalityDetector, deps: [{ token: i1.Platform }, { token: i0.NgZone }, { token: DOCUMENT }, { token: INPUT_MODALITY_DETECTOR_OPTIONS, optional: true }], target: i0.ÉµÉµFactoryTarget.Injectable });\nInputModalityDetector.Éµprov = i0.ÉµÉµngDeclareInjectable({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: InputModalityDetector, providedIn: 'root' });\ni0.ÉµÉµngDeclareClassMetadata({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: InputModalityDetector, decorators: [{\n            type: Injectable,\n            args: [{ providedIn: 'root' }]\n        }], ctorParameters: function () { return [{ type: i1.Platform }, { type: i0.NgZone }, { type: Document, decorators: [{\n                    type: Inject,\n                    args: [DOCUMENT]\n                }] }, { type: undefined, decorators: [{\n                    type: Optional\n                }, {\n                    type: Inject,\n                    args: [INPUT_MODALITY_DETECTOR_OPTIONS]\n                }] }]; } });\n\n/**\n * @license\n * Copyright Google LLC All Rights Reserved.\n *\n * Use of this source code is governed by an MIT-style license that can be\n * found in the LICENSE file at https://angular.io/license\n */\nconst LIVE_ANNOUNCER_ELEMENT_TOKEN = new InjectionToken('liveAnnouncerElement', {\n    providedIn: 'root',\n    factory: LIVE_ANNOUNCER_ELEMENT_TOKEN_FACTORY,\n});\n/** @docs-private */\nfunction LIVE_ANNOUNCER_ELEMENT_TOKEN_FACTORY() {\n    return null;\n}\n/** Injection token that can be used to configure the default options for the LiveAnnouncer. */\nconst LIVE_ANNOUNCER_DEFAULT_OPTIONS = new InjectionToken('LIVE_ANNOUNCER_DEFAULT_OPTIONS');\n\n/**\n * @license\n * Copyright Google LLC All Rights Reserved.\n *\n * Use of this source code is governed by an MIT-style license that can be\n * found in the LICENSE file at https://angular.io/license\n */\nclass LiveAnnouncer {\n    constructor(elementToken, _ngZone, _document, _defaultOptions) {\n        this._ngZone = _ngZone;\n        this._defaultOptions = _defaultOptions;\n        // We inject the live element and document as `any` because the constructor signature cannot\n        // reference browser globals (HTMLElement, Document) on non-browser environments, since having\n        // a class decorator causes TypeScript to preserve the constructor signature types.\n        this._document = _document;\n        this._liveElement = elementToken || this._createLiveElement();\n    }\n    announce(message, ...args) {\n        const defaultOptions = this._defaultOptions;\n        let politeness;\n        let duration;\n        if (args.length === 1 && typeof args[0] === 'number') {\n            duration = args[0];\n        }\n        else {\n            [politeness, duration] = args;\n        }\n        this.clear();\n        clearTimeout(this._previousTimeout);\n        if (!politeness) {\n            politeness =\n                defaultOptions && defaultOptions.politeness ? defaultOptions.politeness : 'polite';\n        }\n        if (duration == null && defaultOptions) {\n            duration = defaultOptions.duration;\n        }\n        // TODO: ensure changing the politeness works on all environments we support.\n        this._liveElement.setAttribute('aria-live', politeness);\n        // This 100ms timeout is necessary for some browser + screen-reader combinations:\n        // - Both JAWS and NVDA over IE11 will not announce anything without a non-zero timeout.\n        // - With Chrome and IE11 with NVDA or JAWS, a repeated (identical) message won't be read a\n        //   second time without clearing and then using a non-zero delay.\n        // (using JAWS 17 at time of this writing).\n        return this._ngZone.runOutsideAngular(() => {\n            return new Promise(resolve => {\n                clearTimeout(this._previousTimeout);\n                this._previousTimeout = setTimeout(() => {\n                    this._liveElement.textContent = message;\n                    resolve();\n                    if (typeof duration === 'number') {\n                        this._previousTimeout = setTimeout(() => this.clear(), duration);\n                    }\n                }, 100);\n            });\n        });\n    }\n    /**\n     * Clears the current text from the announcer element. Can be used to prevent\n     * screen readers from reading the text out again while the user is going\n     * through the page landmarks.\n     */\n    clear() {\n        if (this._liveElement) {\n            this._liveElement.textContent = '';\n        }\n    }\n    ngOnDestroy() {\n        clearTimeout(this._previousTimeout);\n        this._liveElement?.remove();\n        this._liveElement = null;\n    }\n    _createLiveElement() {\n        const elementClass = 'cdk-live-announcer-element';\n        const previousElements = this._document.getElementsByClassName(elementClass);\n        const liveEl = this._document.createElement('div');\n        // Remove any old containers. This can happen when coming in from a server-side-rendered page.\n        for (let i = 0; i < previousElements.length; i++) {\n            previousElements[i].remove();\n        }\n        liveEl.classList.add(elementClass);\n        liveEl.classList.add('cdk-visually-hidden');\n        liveEl.setAttribute('aria-atomic', 'true');\n        liveEl.setAttribute('aria-live', 'polite');\n        this._document.body.appendChild(liveEl);\n        return liveEl;\n    }\n}\nLiveAnnouncer.Éµfac = i0.ÉµÉµngDeclareFactory({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: LiveAnnouncer, deps: [{ token: LIVE_ANNOUNCER_ELEMENT_TOKEN, optional: true }, { token: i0.NgZone }, { token: DOCUMENT }, { token: LIVE_ANNOUNCER_DEFAULT_OPTIONS, optional: true }], target: i0.ÉµÉµFactoryTarget.Injectable });\nLiveAnnouncer.Éµprov = i0.ÉµÉµngDeclareInjectable({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: LiveAnnouncer, providedIn: 'root' });\ni0.ÉµÉµngDeclareClassMetadata({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: LiveAnnouncer, decorators: [{\n            type: Injectable,\n            args: [{ providedIn: 'root' }]\n        }], ctorParameters: function () { return [{ type: undefined, decorators: [{\n                    type: Optional\n                }, {\n                    type: Inject,\n                    args: [LIVE_ANNOUNCER_ELEMENT_TOKEN]\n                }] }, { type: i0.NgZone }, { type: undefined, decorators: [{\n                    type: Inject,\n                    args: [DOCUMENT]\n                }] }, { type: undefined, decorators: [{\n                    type: Optional\n                }, {\n                    type: Inject,\n                    args: [LIVE_ANNOUNCER_DEFAULT_OPTIONS]\n                }] }]; } });\n/**\n * A directive that works similarly to aria-live, but uses the LiveAnnouncer to ensure compatibility\n * with a wider range of browsers and screen readers.\n */\nclass CdkAriaLive {\n    constructor(_elementRef, _liveAnnouncer, _contentObserver, _ngZone) {\n        this._elementRef = _elementRef;\n        this._liveAnnouncer = _liveAnnouncer;\n        this._contentObserver = _contentObserver;\n        this._ngZone = _ngZone;\n        this._politeness = 'polite';\n    }\n    /** The aria-live politeness level to use when announcing messages. */\n    get politeness() {\n        return this._politeness;\n    }\n    set politeness(value) {\n        this._politeness = value === 'off' || value === 'assertive' ? value : 'polite';\n        if (this._politeness === 'off') {\n            if (this._subscription) {\n                this._subscription.unsubscribe();\n                this._subscription = null;\n            }\n        }\n        else if (!this._subscription) {\n            this._subscription = this._ngZone.runOutsideAngular(() => {\n                return this._contentObserver.observe(this._elementRef).subscribe(() => {\n                    // Note that we use textContent here, rather than innerText, in order to avoid a reflow.\n                    const elementText = this._elementRef.nativeElement.textContent;\n                    // The `MutationObserver` fires also for attribute\n                    // changes which we don't want to announce.\n                    if (elementText !== this._previousAnnouncedText) {\n                        this._liveAnnouncer.announce(elementText, this._politeness);\n                        this._previousAnnouncedText = elementText;\n                    }\n                });\n            });\n        }\n    }\n    ngOnDestroy() {\n        if (this._subscription) {\n            this._subscription.unsubscribe();\n        }\n    }\n}\nCdkAriaLive.Éµfac = i0.ÉµÉµngDeclareFactory({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: CdkAriaLive, deps: [{ token: i0.ElementRef }, { token: LiveAnnouncer }, { token: i1$1.ContentObserver }, { token: i0.NgZone }], target: i0.ÉµÉµFactoryTarget.Directive });\nCdkAriaLive.Éµdir = i0.ÉµÉµngDeclareDirective({ minVersion: \"12.0.0\", version: \"13.0.1\", type: CdkAriaLive, selector: \"[cdkAriaLive]\", inputs: { politeness: [\"cdkAriaLive\", \"politeness\"] }, exportAs: [\"cdkAriaLive\"], ngImport: i0 });\ni0.ÉµÉµngDeclareClassMetadata({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: CdkAriaLive, decorators: [{\n            type: Directive,\n            args: [{\n                    selector: '[cdkAriaLive]',\n                    exportAs: 'cdkAriaLive',\n                }]\n        }], ctorParameters: function () { return [{ type: i0.ElementRef }, { type: LiveAnnouncer }, { type: i1$1.ContentObserver }, { type: i0.NgZone }]; }, propDecorators: { politeness: [{\n                type: Input,\n                args: ['cdkAriaLive']\n            }] } });\n\n/**\n * @license\n * Copyright Google LLC All Rights Reserved.\n *\n * Use of this source code is governed by an MIT-style license that can be\n * found in the LICENSE file at https://angular.io/license\n */\n/** InjectionToken for FocusMonitorOptions. */\nconst FOCUS_MONITOR_DEFAULT_OPTIONS = new InjectionToken('cdk-focus-monitor-default-options');\n/**\n * Event listener options that enable capturing and also\n * mark the listener as passive if the browser supports it.\n */\nconst captureEventListenerOptions = normalizePassiveListenerOptions({\n    passive: true,\n    capture: true,\n});\n/** Monitors mouse and keyboard events to determine the cause of focus events. */\nclass FocusMonitor {\n    constructor(_ngZone, _platform, _inputModalityDetector, \n    /** @breaking-change 11.0.0 make document required */\n    document, options) {\n        this._ngZone = _ngZone;\n        this._platform = _platform;\n        this._inputModalityDetector = _inputModalityDetector;\n        /** The focus origin that the next focus event is a result of. */\n        this._origin = null;\n        /** Whether the window has just been focused. */\n        this._windowFocused = false;\n        /**\n         * Whether the origin was determined via a touch interaction. Necessary as properly attributing\n         * focus events to touch interactions requires special logic.\n         */\n        this._originFromTouchInteraction = false;\n        /** Map of elements being monitored to their info. */\n        this._elementInfo = new Map();\n        /** The number of elements currently being monitored. */\n        this._monitoredElementCount = 0;\n        /**\n         * Keeps track of the root nodes to which we've currently bound a focus/blur handler,\n         * as well as the number of monitored elements that they contain. We have to treat focus/blur\n         * handlers differently from the rest of the events, because the browser won't emit events\n         * to the document when focus moves inside of a shadow root.\n         */\n        this._rootNodeFocusListenerCount = new Map();\n        /**\n         * Event listener for `focus` events on the window.\n         * Needs to be an arrow function in order to preserve the context when it gets bound.\n         */\n        this._windowFocusListener = () => {\n            // Make a note of when the window regains focus, so we can\n            // restore the origin info for the focused element.\n            this._windowFocused = true;\n            this._windowFocusTimeoutId = setTimeout(() => (this._windowFocused = false));\n        };\n        /** Subject for stopping our InputModalityDetector subscription. */\n        this._stopInputModalityDetector = new Subject();\n        /**\n         * Event listener for `focus` and 'blur' events on the document.\n         * Needs to be an arrow function in order to preserve the context when it gets bound.\n         */\n        this._rootNodeFocusAndBlurListener = (event) => {\n            const target = _getEventTarget(event);\n            const handler = event.type === 'focus' ? this._onFocus : this._onBlur;\n            // We need to walk up the ancestor chain in order to support `checkChildren`.\n            for (let element = target; element; element = element.parentElement) {\n                handler.call(this, event, element);\n            }\n        };\n        this._document = document;\n        this._detectionMode = options?.detectionMode || 0 /* IMMEDIATE */;\n    }\n    monitor(element, checkChildren = false) {\n        const nativeElement = coerceElement(element);\n        // Do nothing if we're not on the browser platform or the passed in node isn't an element.\n        if (!this._platform.isBrowser || nativeElement.nodeType !== 1) {\n            return of(null);\n        }\n        // If the element is inside the shadow DOM, we need to bind our focus/blur listeners to\n        // the shadow root, rather than the `document`, because the browser won't emit focus events\n        // to the `document`, if focus is moving within the same shadow root.\n        const rootNode = _getShadowRoot(nativeElement) || this._getDocument();\n        const cachedInfo = this._elementInfo.get(nativeElement);\n        // Check if we're already monitoring this element.\n        if (cachedInfo) {\n            if (checkChildren) {\n                // TODO(COMP-318): this can be problematic, because it'll turn all non-checkChildren\n                // observers into ones that behave as if `checkChildren` was turned on. We need a more\n                // robust solution.\n                cachedInfo.checkChildren = true;\n            }\n            return cachedInfo.subject;\n        }\n        // Create monitored element info.\n        const info = {\n            checkChildren: checkChildren,\n            subject: new Subject(),\n            rootNode,\n        };\n        this._elementInfo.set(nativeElement, info);\n        this._registerGlobalListeners(info);\n        return info.subject;\n    }\n    stopMonitoring(element) {\n        const nativeElement = coerceElement(element);\n        const elementInfo = this._elementInfo.get(nativeElement);\n        if (elementInfo) {\n            elementInfo.subject.complete();\n            this._setClasses(nativeElement);\n            this._elementInfo.delete(nativeElement);\n            this._removeGlobalListeners(elementInfo);\n        }\n    }\n    focusVia(element, origin, options) {\n        const nativeElement = coerceElement(element);\n        const focusedElement = this._getDocument().activeElement;\n        // If the element is focused already, calling `focus` again won't trigger the event listener\n        // which means that the focus classes won't be updated. If that's the case, update the classes\n        // directly without waiting for an event.\n        if (nativeElement === focusedElement) {\n            this._getClosestElementsInfo(nativeElement).forEach(([currentElement, info]) => this._originChanged(currentElement, origin, info));\n        }\n        else {\n            this._setOrigin(origin);\n            // `focus` isn't available on the server\n            if (typeof nativeElement.focus === 'function') {\n                nativeElement.focus(options);\n            }\n        }\n    }\n    ngOnDestroy() {\n        this._elementInfo.forEach((_info, element) => this.stopMonitoring(element));\n    }\n    /** Access injected document if available or fallback to global document reference */\n    _getDocument() {\n        return this._document || document;\n    }\n    /** Use defaultView of injected document if available or fallback to global window reference */\n    _getWindow() {\n        const doc = this._getDocument();\n        return doc.defaultView || window;\n    }\n    _getFocusOrigin(focusEventTarget) {\n        if (this._origin) {\n            // If the origin was realized via a touch interaction, we need to perform additional checks\n            // to determine whether the focus origin should be attributed to touch or program.\n            if (this._originFromTouchInteraction) {\n                return this._shouldBeAttributedToTouch(focusEventTarget) ? 'touch' : 'program';\n            }\n            else {\n                return this._origin;\n            }\n        }\n        // If the window has just regained focus, we can restore the most recent origin from before the\n        // window blurred. Otherwise, we've reached the point where we can't identify the source of the\n        // focus. This typically means one of two things happened:\n        //\n        // 1) The element was programmatically focused, or\n        // 2) The element was focused via screen reader navigation (which generally doesn't fire\n        //    events).\n        //\n        // Because we can't distinguish between these two cases, we default to setting `program`.\n        return this._windowFocused && this._lastFocusOrigin ? this._lastFocusOrigin : 'program';\n    }\n    /**\n     * Returns whether the focus event should be attributed to touch. Recall that in IMMEDIATE mode, a\n     * touch origin isn't immediately reset at the next tick (see _setOrigin). This means that when we\n     * handle a focus event following a touch interaction, we need to determine whether (1) the focus\n     * event was directly caused by the touch interaction or (2) the focus event was caused by a\n     * subsequent programmatic focus call triggered by the touch interaction.\n     * @param focusEventTarget The target of the focus event under examination.\n     */\n    _shouldBeAttributedToTouch(focusEventTarget) {\n        // Please note that this check is not perfect. Consider the following edge case:\n        //\n        // <div #parent tabindex=\"0\">\n        //   <div #child tabindex=\"0\" (click)=\"#parent.focus()\"></div>\n        // </div>\n        //\n        // Suppose there is a FocusMonitor in IMMEDIATE mode attached to #parent. When the user touches\n        // #child, #parent is programmatically focused. This code will attribute the focus to touch\n        // instead of program. This is a relatively minor edge-case that can be worked around by using\n        // focusVia(parent, 'program') to focus #parent.\n        return (this._detectionMode === 1 /* EVENTUAL */ ||\n            !!focusEventTarget?.contains(this._inputModalityDetector._mostRecentTarget));\n    }\n    /**\n     * Sets the focus classes on the element based on the given focus origin.\n     * @param element The element to update the classes on.\n     * @param origin The focus origin.\n     */\n    _setClasses(element, origin) {\n        element.classList.toggle('cdk-focused', !!origin);\n        element.classList.toggle('cdk-touch-focused', origin === 'touch');\n        element.classList.toggle('cdk-keyboard-focused', origin === 'keyboard');\n        element.classList.toggle('cdk-mouse-focused', origin === 'mouse');\n        element.classList.toggle('cdk-program-focused', origin === 'program');\n    }\n    /**\n     * Updates the focus origin. If we're using immediate detection mode, we schedule an async\n     * function to clear the origin at the end of a timeout. The duration of the timeout depends on\n     * the origin being set.\n     * @param origin The origin to set.\n     * @param isFromInteraction Whether we are setting the origin from an interaction event.\n     */\n    _setOrigin(origin, isFromInteraction = false) {\n        this._ngZone.runOutsideAngular(() => {\n            this._origin = origin;\n            this._originFromTouchInteraction = origin === 'touch' && isFromInteraction;\n            // If we're in IMMEDIATE mode, reset the origin at the next tick (or in `TOUCH_BUFFER_MS` ms\n            // for a touch event). We reset the origin at the next tick because Firefox focuses one tick\n            // after the interaction event. We wait `TOUCH_BUFFER_MS` ms before resetting the origin for\n            // a touch event because when a touch event is fired, the associated focus event isn't yet in\n            // the event queue. Before doing so, clear any pending timeouts.\n            if (this._detectionMode === 0 /* IMMEDIATE */) {\n                clearTimeout(this._originTimeoutId);\n                const ms = this._originFromTouchInteraction ? TOUCH_BUFFER_MS : 1;\n                this._originTimeoutId = setTimeout(() => (this._origin = null), ms);\n            }\n        });\n    }\n    /**\n     * Handles focus events on a registered element.\n     * @param event The focus event.\n     * @param element The monitored element.\n     */\n    _onFocus(event, element) {\n        // NOTE(mmalerba): We currently set the classes based on the focus origin of the most recent\n        // focus event affecting the monitored element. If we want to use the origin of the first event\n        // instead we should check for the cdk-focused class here and return if the element already has\n        // it. (This only matters for elements that have includesChildren = true).\n        // If we are not counting child-element-focus as focused, make sure that the event target is the\n        // monitored element itself.\n        const elementInfo = this._elementInfo.get(element);\n        const focusEventTarget = _getEventTarget(event);\n        if (!elementInfo || (!elementInfo.checkChildren && element !== focusEventTarget)) {\n            return;\n        }\n        this._originChanged(element, this._getFocusOrigin(focusEventTarget), elementInfo);\n    }\n    /**\n     * Handles blur events on a registered element.\n     * @param event The blur event.\n     * @param element The monitored element.\n     */\n    _onBlur(event, element) {\n        // If we are counting child-element-focus as focused, make sure that we aren't just blurring in\n        // order to focus another child of the monitored element.\n        const elementInfo = this._elementInfo.get(element);\n        if (!elementInfo ||\n            (elementInfo.checkChildren &&\n                event.relatedTarget instanceof Node &&\n                element.contains(event.relatedTarget))) {\n            return;\n        }\n        this._setClasses(element);\n        this._emitOrigin(elementInfo.subject, null);\n    }\n    _emitOrigin(subject, origin) {\n        this._ngZone.run(() => subject.next(origin));\n    }\n    _registerGlobalListeners(elementInfo) {\n        if (!this._platform.isBrowser) {\n            return;\n        }\n        const rootNode = elementInfo.rootNode;\n        const rootNodeFocusListeners = this._rootNodeFocusListenerCount.get(rootNode) || 0;\n        if (!rootNodeFocusListeners) {\n            this._ngZone.runOutsideAngular(() => {\n                rootNode.addEventListener('focus', this._rootNodeFocusAndBlurListener, captureEventListenerOptions);\n                rootNode.addEventListener('blur', this._rootNodeFocusAndBlurListener, captureEventListenerOptions);\n            });\n        }\n        this._rootNodeFocusListenerCount.set(rootNode, rootNodeFocusListeners + 1);\n        // Register global listeners when first element is monitored.\n        if (++this._monitoredElementCount === 1) {\n            // Note: we listen to events in the capture phase so we\n            // can detect them even if the user stops propagation.\n            this._ngZone.runOutsideAngular(() => {\n                const window = this._getWindow();\n                window.addEventListener('focus', this._windowFocusListener);\n            });\n            // The InputModalityDetector is also just a collection of global listeners.\n            this._inputModalityDetector.modalityDetected\n                .pipe(takeUntil(this._stopInputModalityDetector))\n                .subscribe(modality => {\n                this._setOrigin(modality, true /* isFromInteraction */);\n            });\n        }\n    }\n    _removeGlobalListeners(elementInfo) {\n        const rootNode = elementInfo.rootNode;\n        if (this._rootNodeFocusListenerCount.has(rootNode)) {\n            const rootNodeFocusListeners = this._rootNodeFocusListenerCount.get(rootNode);\n            if (rootNodeFocusListeners > 1) {\n                this._rootNodeFocusListenerCount.set(rootNode, rootNodeFocusListeners - 1);\n            }\n            else {\n                rootNode.removeEventListener('focus', this._rootNodeFocusAndBlurListener, captureEventListenerOptions);\n                rootNode.removeEventListener('blur', this._rootNodeFocusAndBlurListener, captureEventListenerOptions);\n                this._rootNodeFocusListenerCount.delete(rootNode);\n            }\n        }\n        // Unregister global listeners when last element is unmonitored.\n        if (!--this._monitoredElementCount) {\n            const window = this._getWindow();\n            window.removeEventListener('focus', this._windowFocusListener);\n            // Equivalently, stop our InputModalityDetector subscription.\n            this._stopInputModalityDetector.next();\n            // Clear timeouts for all potentially pending timeouts to prevent the leaks.\n            clearTimeout(this._windowFocusTimeoutId);\n            clearTimeout(this._originTimeoutId);\n        }\n    }\n    /** Updates all the state on an element once its focus origin has changed. */\n    _originChanged(element, origin, elementInfo) {\n        this._setClasses(element, origin);\n        this._emitOrigin(elementInfo.subject, origin);\n        this._lastFocusOrigin = origin;\n    }\n    /**\n     * Collects the `MonitoredElementInfo` of a particular element and\n     * all of its ancestors that have enabled `checkChildren`.\n     * @param element Element from which to start the search.\n     */\n    _getClosestElementsInfo(element) {\n        const results = [];\n        this._elementInfo.forEach((info, currentElement) => {\n            if (currentElement === element || (info.checkChildren && currentElement.contains(element))) {\n                results.push([currentElement, info]);\n            }\n        });\n        return results;\n    }\n}\nFocusMonitor.Éµfac = i0.ÉµÉµngDeclareFactory({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: FocusMonitor, deps: [{ token: i0.NgZone }, { token: i1.Platform }, { token: InputModalityDetector }, { token: DOCUMENT, optional: true }, { token: FOCUS_MONITOR_DEFAULT_OPTIONS, optional: true }], target: i0.ÉµÉµFactoryTarget.Injectable });\nFocusMonitor.Éµprov = i0.ÉµÉµngDeclareInjectable({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: FocusMonitor, providedIn: 'root' });\ni0.ÉµÉµngDeclareClassMetadata({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: FocusMonitor, decorators: [{\n            type: Injectable,\n            args: [{ providedIn: 'root' }]\n        }], ctorParameters: function () { return [{ type: i0.NgZone }, { type: i1.Platform }, { type: InputModalityDetector }, { type: undefined, decorators: [{\n                    type: Optional\n                }, {\n                    type: Inject,\n                    args: [DOCUMENT]\n                }] }, { type: undefined, decorators: [{\n                    type: Optional\n                }, {\n                    type: Inject,\n                    args: [FOCUS_MONITOR_DEFAULT_OPTIONS]\n                }] }]; } });\n/**\n * Directive that determines how a particular element was focused (via keyboard, mouse, touch, or\n * programmatically) and adds corresponding classes to the element.\n *\n * There are two variants of this directive:\n * 1) cdkMonitorElementFocus: does not consider an element to be focused if one of its children is\n *    focused.\n * 2) cdkMonitorSubtreeFocus: considers an element focused if it or any of its children are focused.\n */\nclass CdkMonitorFocus {\n    constructor(_elementRef, _focusMonitor) {\n        this._elementRef = _elementRef;\n        this._focusMonitor = _focusMonitor;\n        this.cdkFocusChange = new EventEmitter();\n    }\n    ngAfterViewInit() {\n        const element = this._elementRef.nativeElement;\n        this._monitorSubscription = this._focusMonitor\n            .monitor(element, element.nodeType === 1 && element.hasAttribute('cdkMonitorSubtreeFocus'))\n            .subscribe(origin => this.cdkFocusChange.emit(origin));\n    }\n    ngOnDestroy() {\n        this._focusMonitor.stopMonitoring(this._elementRef);\n        if (this._monitorSubscription) {\n            this._monitorSubscription.unsubscribe();\n        }\n    }\n}\nCdkMonitorFocus.Éµfac = i0.ÉµÉµngDeclareFactory({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: CdkMonitorFocus, deps: [{ token: i0.ElementRef }, { token: FocusMonitor }], target: i0.ÉµÉµFactoryTarget.Directive });\nCdkMonitorFocus.Éµdir = i0.ÉµÉµngDeclareDirective({ minVersion: \"12.0.0\", version: \"13.0.1\", type: CdkMonitorFocus, selector: \"[cdkMonitorElementFocus], [cdkMonitorSubtreeFocus]\", outputs: { cdkFocusChange: \"cdkFocusChange\" }, ngImport: i0 });\ni0.ÉµÉµngDeclareClassMetadata({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: CdkMonitorFocus, decorators: [{\n            type: Directive,\n            args: [{\n                    selector: '[cdkMonitorElementFocus], [cdkMonitorSubtreeFocus]',\n                }]\n        }], ctorParameters: function () { return [{ type: i0.ElementRef }, { type: FocusMonitor }]; }, propDecorators: { cdkFocusChange: [{\n                type: Output\n            }] } });\n\n/**\n * @license\n * Copyright Google LLC All Rights Reserved.\n *\n * Use of this source code is governed by an MIT-style license that can be\n * found in the LICENSE file at https://angular.io/license\n */\n/** CSS class applied to the document body when in black-on-white high-contrast mode. */\nconst BLACK_ON_WHITE_CSS_CLASS = 'cdk-high-contrast-black-on-white';\n/** CSS class applied to the document body when in white-on-black high-contrast mode. */\nconst WHITE_ON_BLACK_CSS_CLASS = 'cdk-high-contrast-white-on-black';\n/** CSS class applied to the document body when in high-contrast mode. */\nconst HIGH_CONTRAST_MODE_ACTIVE_CSS_CLASS = 'cdk-high-contrast-active';\n/**\n * Service to determine whether the browser is currently in a high-contrast-mode environment.\n *\n * Microsoft Windows supports an accessibility feature called \"High Contrast Mode\". This mode\n * changes the appearance of all applications, including web applications, to dramatically increase\n * contrast.\n *\n * IE, Edge, and Firefox currently support this mode. Chrome does not support Windows High Contrast\n * Mode. This service does not detect high-contrast mode as added by the Chrome \"High Contrast\"\n * browser extension.\n */\nclass HighContrastModeDetector {\n    constructor(_platform, document) {\n        this._platform = _platform;\n        this._document = document;\n    }\n    /** Gets the current high-contrast-mode for the page. */\n    getHighContrastMode() {\n        if (!this._platform.isBrowser) {\n            return 0 /* NONE */;\n        }\n        // Create a test element with an arbitrary background-color that is neither black nor\n        // white; high-contrast mode will coerce the color to either black or white. Also ensure that\n        // appending the test element to the DOM does not affect layout by absolutely positioning it\n        const testElement = this._document.createElement('div');\n        testElement.style.backgroundColor = 'rgb(1,2,3)';\n        testElement.style.position = 'absolute';\n        this._document.body.appendChild(testElement);\n        // Get the computed style for the background color, collapsing spaces to normalize between\n        // browsers. Once we get this color, we no longer need the test element. Access the `window`\n        // via the document so we can fake it in tests. Note that we have extra null checks, because\n        // this logic will likely run during app bootstrap and throwing can break the entire app.\n        const documentWindow = this._document.defaultView || window;\n        const computedStyle = documentWindow && documentWindow.getComputedStyle\n            ? documentWindow.getComputedStyle(testElement)\n            : null;\n        const computedColor = ((computedStyle && computedStyle.backgroundColor) || '').replace(/ /g, '');\n        testElement.remove();\n        switch (computedColor) {\n            case 'rgb(0,0,0)':\n                return 2 /* WHITE_ON_BLACK */;\n            case 'rgb(255,255,255)':\n                return 1 /* BLACK_ON_WHITE */;\n        }\n        return 0 /* NONE */;\n    }\n    /** Applies CSS classes indicating high-contrast mode to document body (browser-only). */\n    _applyBodyHighContrastModeCssClasses() {\n        if (!this._hasCheckedHighContrastMode && this._platform.isBrowser && this._document.body) {\n            const bodyClasses = this._document.body.classList;\n            // IE11 doesn't support `classList` operations with multiple arguments\n            bodyClasses.remove(HIGH_CONTRAST_MODE_ACTIVE_CSS_CLASS);\n            bodyClasses.remove(BLACK_ON_WHITE_CSS_CLASS);\n            bodyClasses.remove(WHITE_ON_BLACK_CSS_CLASS);\n            this._hasCheckedHighContrastMode = true;\n            const mode = this.getHighContrastMode();\n            if (mode === 1 /* BLACK_ON_WHITE */) {\n                bodyClasses.add(HIGH_CONTRAST_MODE_ACTIVE_CSS_CLASS);\n                bodyClasses.add(BLACK_ON_WHITE_CSS_CLASS);\n            }\n            else if (mode === 2 /* WHITE_ON_BLACK */) {\n                bodyClasses.add(HIGH_CONTRAST_MODE_ACTIVE_CSS_CLASS);\n                bodyClasses.add(WHITE_ON_BLACK_CSS_CLASS);\n            }\n        }\n    }\n}\nHighContrastModeDetector.Éµfac = i0.ÉµÉµngDeclareFactory({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: HighContrastModeDetector, deps: [{ token: i1.Platform }, { token: DOCUMENT }], target: i0.ÉµÉµFactoryTarget.Injectable });\nHighContrastModeDetector.Éµprov = i0.ÉµÉµngDeclareInjectable({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: HighContrastModeDetector, providedIn: 'root' });\ni0.ÉµÉµngDeclareClassMetadata({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: HighContrastModeDetector, decorators: [{\n            type: Injectable,\n            args: [{ providedIn: 'root' }]\n        }], ctorParameters: function () { return [{ type: i1.Platform }, { type: undefined, decorators: [{\n                    type: Inject,\n                    args: [DOCUMENT]\n                }] }]; } });\n\n/**\n * @license\n * Copyright Google LLC All Rights Reserved.\n *\n * Use of this source code is governed by an MIT-style license that can be\n * found in the LICENSE file at https://angular.io/license\n */\nclass A11yModule {\n    constructor(highContrastModeDetector) {\n        highContrastModeDetector._applyBodyHighContrastModeCssClasses();\n    }\n}\nA11yModule.Éµfac = i0.ÉµÉµngDeclareFactory({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: A11yModule, deps: [{ token: HighContrastModeDetector }], target: i0.ÉµÉµFactoryTarget.NgModule });\nA11yModule.Éµmod = i0.ÉµÉµngDeclareNgModule({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: A11yModule, declarations: [CdkAriaLive, CdkTrapFocus, CdkMonitorFocus], imports: [PlatformModule, ObserversModule], exports: [CdkAriaLive, CdkTrapFocus, CdkMonitorFocus] });\nA11yModule.Éµinj = i0.ÉµÉµngDeclareInjector({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: A11yModule, imports: [[PlatformModule, ObserversModule]] });\ni0.ÉµÉµngDeclareClassMetadata({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: A11yModule, decorators: [{\n            type: NgModule,\n            args: [{\n                    imports: [PlatformModule, ObserversModule],\n                    declarations: [CdkAriaLive, CdkTrapFocus, CdkMonitorFocus],\n                    exports: [CdkAriaLive, CdkTrapFocus, CdkMonitorFocus],\n                }]\n        }], ctorParameters: function () { return [{ type: HighContrastModeDetector }]; } });\n\n/**\n * @license\n * Copyright Google LLC All Rights Reserved.\n *\n * Use of this source code is governed by an MIT-style license that can be\n * found in the LICENSE file at https://angular.io/license\n */\n\n/**\n * @license\n * Copyright Google LLC All Rights Reserved.\n *\n * Use of this source code is governed by an MIT-style license that can be\n * found in the LICENSE file at https://angular.io/license\n */\n\n/**\n * Generated bundle index. Do not edit.\n */\n\nexport { A11yModule, ActiveDescendantKeyManager, AriaDescriber, CDK_DESCRIBEDBY_HOST_ATTRIBUTE, CDK_DESCRIBEDBY_ID_PREFIX, CdkAriaLive, CdkMonitorFocus, CdkTrapFocus, ConfigurableFocusTrap, ConfigurableFocusTrapFactory, EventListenerFocusTrapInertStrategy, FOCUS_MONITOR_DEFAULT_OPTIONS, FOCUS_TRAP_INERT_STRATEGY, FocusKeyManager, FocusMonitor, FocusTrap, FocusTrapFactory, HighContrastModeDetector, INPUT_MODALITY_DETECTOR_DEFAULT_OPTIONS, INPUT_MODALITY_DETECTOR_OPTIONS, InputModalityDetector, InteractivityChecker, IsFocusableConfig, LIVE_ANNOUNCER_DEFAULT_OPTIONS, LIVE_ANNOUNCER_ELEMENT_TOKEN, LIVE_ANNOUNCER_ELEMENT_TOKEN_FACTORY, ListKeyManager, LiveAnnouncer, MESSAGES_CONTAINER_ID, isFakeMousedownFromScreenReader, isFakeTouchstartFromScreenReader };\n"],"file":"x"}‹exportsType“strictHarmonyModule‰namespacejavascript/esm¾D:\GitHub\Neetechs_Frontend\node_modules\@angular\cdk\fesm2020fullySpecifiedsideEffectFreeù`‰cacheable†parsedfileDependencies“contextDependencies“missingDependencies‘buildDependencies‘valueDependencies„hash†assetsŠassetsInfo†strictexportsArgumentmoduleArgument”topLevelDeclarationsˆsnapshot˜webpack/lib/util/LazySetâD:\GitHub\Neetechs_Frontend\node_modules\@angular-devkit\build-angular\src\babel\webpack-loader.jsÆD:\GitHub\Neetechs_Frontend\node_modules\source-map-loader\dist\cjs.js™webpack/DefinePlugin_hashˆbffc37a8f260dfd6348ee173“__webpack_exports__’__webpack_module__€`;“addAriaReferencedId–removeAriaReferencedId“getAriaReferenceIds†getKeyŒsetMessageIdgetFrameElement‹hasGeometry“isNativeFormElementisHiddenInputisAnchorWithHrefisInputElementisAnchorElementhasValidTabIndexgetTabIndexValue˜isPotentiallyTabbableIOS–isPotentiallyFocusable‰getWindowŸisFakeMousedownFromScreenReader isFakeTouchstartFromScreenReader¤LIVE_ANNOUNCER_ELEMENT_TOKEN_FACTORYŒID_DELIMITER•MESSAGES_CONTAINER_ID™CDK_DESCRIBEDBY_ID_PREFIXCDK_DESCRIBEDBY_HOST_ATTRIBUTE†nextIdmessageRegistry‘messagesContainerAriaDescriberListKeyManageršActiveDescendantKeyManagerFocusKeyManager‘IsFocusableConfig”InteractivityChecker‰FocusTrapFocusTrapFactoryŒCdkTrapFocus•ConfigurableFocusTrap™FOCUS_TRAP_INERT_STRATEGY£EventListenerFocusTrapInertStrategyFocusTrapManagerœConfigurableFocusTrapFactoryŸINPUT_MODALITY_DETECTOR_OPTIONS§INPUT_MODALITY_DETECTOR_DEFAULT_OPTIONSTOUCH_BUFFER_MSœmodalityEventListenerOptions•InputModalityDetectorœLIVE_ANNOUNCER_ELEMENT_TOKENLIVE_ANNOUNCER_DEFAULT_OPTIONSLiveAnnouncer‹CdkAriaLiveFOCUS_MONITOR_DEFAULT_OPTIONS›captureEventListenerOptionsŒFocusMonitorCdkMonitorFocus˜BLACK_ON_WHITE_CSS_CLASS˜WHITE_ON_BLACK_CSS_CLASS£HIGH_CONTRAST_MODE_ACTIVE_CSS_CLASS˜HighContrastModeDetectorŠA11yModule@    ğÆÚÒwB	µD:\GitHub\Neetechs_Frontend\node_modules\@angular\cdk“@angular/cdk@13.0.1ÇD:\GitHub\Neetechs_Frontend\node_modules\@angular\cdk\fesm2020\a11y.mjs`·webpack/lib/dependencies/HarmonyCompatibilityDependencydÿ ÿ ı¨webpack/lib/dependencies/ConstDependency€ `+ `+€a,P `$€`Q@Û    @Š   €AÜ      `B€A  Ì   @­   €AÍ  :   `m€A;  ˆ   `M€A‰  µ   `,€A¶  R  	 	@œ   €AS  ‚  
 
`/€Aƒ  ¼  c 9¶webpack/lib/dependencies/HarmonyExportHeaderDependency Ac \„ @K   AK  ù  @ô   ºwebpack/lib/dependencies/HarmonyImportSideEffectDependency@angular/commonÿ `+@angular/coreÿ `$şş @Š   „rxjsÿ `B•@angular/cdk/keycodesÿ @­   rxjs/operatorsÿ `m•@angular/cdk/coercionÿ `M•@angular/cdk/platformÿ `,	şş	 	@œ   
–@angular/cdk/observersÿ
 
`/`şşc 9¹webpack/lib/dependencies/HarmonyImportSpecifierDependency

   ÉµÉµinject‚i0
A¼*  Ç*  ëëÿ@5  `"@5  `-
ˆDOCUMENTş
AÈ*  Ğ*  ååÿ@5  `.@5  `6
   ÉµÉµdefineInjectable÷
Aı*  +  ããÿ@8  `%@8  `:
   ÉµsetClassMetadataó
Aª+  ¾+  ßßÿ@?  `5@?  `I
ŠInjectableş
AÛ+  å+  ÛÛÿ@@  
@@  `
†Injectş
Ap,  v,  ××ÿ@H  `@H  `íì
A‡,  ,  ÓÓÿ@I  `@I  `
‡Subjectş
Aj0  q0  ÔÔÿ@p  ` @p  `'
ŒSubscription…EMPTYı
A—0  ©0  ÏÏÿ@q  `"@q  `4ø÷
A	3  3  ÍÍÿ@ƒ  `@ƒ  `öõ
A~3  …3  ËËÿ@†  `@†  `
‰QueryListş
Aš4  £4  ÄÄÿ@Š  `@Š  `#
ƒtapş
A?  ?  ÇÇÿ@Ü  `=@Ü  `@
ŒdebounceTimeş
AJ?  V?  ÃÃÿ@Ü  `o@Ü  `{
†filterş
Aj?  p?  ¿¿ÿCÜ     Ü  •   
ƒmapş
A™?  œ?  »»ÿCÜ  ¾   Ü  Á   
ƒTABş
AF  F  µµÿ@  `@  `
ŠDOWN_ARROWş
A>F  HF  ±±ÿ@  `@  `
ˆUP_ARROWş
AëF  óF  ­­ÿ@  `@  `
‹RIGHT_ARROWş
AšG  ¥G  ©©ÿ@%  `@%  `
ŠLEFT_ARROWş
A†H  H  ¥¥ÿ@-  `@-  `
„HOMEş
AqI  uI  ¡¡ÿ@5  `@5  `
ƒENDş
AJ  J  ÿ@=  `@=  `
hasModifierKeyş
AèJ  öJ  ™™ÿ@F  `!@F  `/
AA
A`L  aL  ––ÿ@K  ` @K  `!
ZZ
ApL  qL  ““ÿ@K  `0@K  `1
„ZEROş
A€L  „L  ÿ@K  `@@K  `D
„NINEş
A“L  —L  ‹‹ÿ@K  `S@K  `W¿¾
A[  [  „„ÿ@Ğ  `"@Ğ  `+
”•
ANt  Yt  ÿ@¯  `)@¯  `4
ˆPlatform‚i1
AZt  et  ‡‡ÿ@¯  `5@¯  `@
•
A™t  ®t  yÿÿÿyÿÿÿÿ@²  `,@²  `A
–Š
ATu  hu  vÿÿÿvÿÿÿÿ@¹  `5@¹  `I˜—
AŒu  –u  tÿÿÿtÿÿÿÿ@º  
@º  `
óô
Aóu  şu  |ÿÿÿ|ÿÿÿÿ@À  `@À  `
„takeş
Aæ«  ê«  tÿÿÿtÿÿÿÿ@  `!@  `%
}ÿÿÿ~ÿÿÿ
Aˆ¯  “¯  jÿÿÿjÿÿÿÿ@¡  `%@¡  `0
zÿÿÿ{ÿÿÿ
A«¯  ¶¯  gÿÿÿgÿÿÿÿ@¡  `H@¡  `S
†NgZonewÿÿÿ
A·¯  À¯  cÿÿÿcÿÿÿÿ@¡  `T@¡  `]
sÿÿÿtÿÿÿ
AÃ¯  Î¯  `ÿÿÿ`ÿÿÿÿ@¡  ``@¡  `kvÿÿÿuÿÿÿ
AÏ¯  ×¯  \ÿÿÿ\ÿÿÿÿ@¡  `l@¡  `t
wÿÿÿoÿÿÿ
A°  °  [ÿÿÿ[ÿÿÿÿ@¤  `(@¤  `=
xÿÿÿlÿÿÿ
Aº°  Î°  XÿÿÿXÿÿÿÿ@«  `5@«  `Izÿÿÿyÿÿÿ
Aî°  ø°  VÿÿÿVÿÿÿÿ@¬  
@¬  `
ïgÿÿÿ
A±  ˆ±  SÿÿÿSÿÿÿÿ@´  `@´  `yÿÿÿxÿÿÿ
AÌ±  Ò±  QÿÿÿQÿÿÿÿ@¸  `@¸  `gÿÿÿfÿÿÿ
Aã±  ë±  MÿÿÿMÿÿÿÿ@¹  `@¹  `
•coerceBooleanPropertyş
AĞ´  å´  TÿÿÿTÿÿÿÿ@×  `@×  `2
üû
A¶  .¶  QÿÿÿQÿÿÿÿ@ä  `@ä  `-
¡_getFocusedElementPierceShadowDomş
A¥¹  Æ¹  	OÿÿÿOÿÿÿÿ@	  `%@	  `F
   ÉµÉµdirectiveInjectTÿÿÿ
A]º  qº  @ÿÿÿ@ÿÿÿÿ@  `!@  `5
ŠElementRefPÿÿÿ
Arº  º  <ÿÿÿ<ÿÿÿÿ@  `6@  `C
øMÿÿÿ
A‚º  –º  9ÿÿÿ9ÿÿÿÿ@  `F@  `Z
õJÿÿÿ
Aªº  ¾º  6ÿÿÿ6ÿÿÿÿ@  `nA  ‚   LÿÿÿKÿÿÿ
A¿º  Çº  2ÿÿÿ2ÿÿÿÿC  ƒ     ‹   
   ÉµÉµdefineDirectiveDÿÿÿ
Aòº  »  0ÿÿÿ0ÿÿÿÿ@  `#@  `7
   ÉµÉµNgOnChangesFeature@ÿÿÿ
Aê»  ¼  ,ÿÿÿ,ÿÿÿÿ@  `@  `$
Iÿÿÿ=ÿÿÿ
AL¼  `¼  )ÿÿÿ)ÿÿÿÿ@  `5@  `I
‰Directiveş
A|¼  …¼  %ÿÿÿ%ÿÿÿÿ@   
@   `
å6ÿÿÿ
A
½  ½  "ÿÿÿ"ÿÿÿÿ@'  `@'  `HÿÿÿGÿÿÿ
A½  ‡½   ÿÿÿ ÿÿÿÿ@-  `@-  `6ÿÿÿ5ÿÿÿ
A˜½   ½  ÿÿÿÿÿÿÿ@.  `@.  `
…Inputş
AÖ½  Û½  ÿÿÿÿÿÿÿ@3  `@3  `ıü
A"¾  '¾  ÿÿÿÿÿÿÿ@7  `@7  `
InjectionTokenş
AAÆ  OÆ  ÿÿÿÿÿÿÿ@‘  `&@‘  `4
-ÿÿÿ%ÿÿÿ
AFÕ  [Õ  ÿÿÿÿÿÿÿ@  `(@  `=
.ÿÿÿ"ÿÿÿ
AùÕ  Ö  ÿÿÿÿÿÿÿ@!  `5@!  `I0ÿÿÿ/ÿÿÿ
A-Ö  7Ö  ÿÿÿÿÿÿÿ@"  
@"  `
ÿÿÿÿÿÿ
AEÛ  PÛ  	ÿÿÿ	ÿÿÿÿ@P  `1@P  `<
ÿÿÿÿÿÿ
AhÛ  sÛ  ÿÿÿÿÿÿÿ@P  `T@P  `_
Ÿÿÿÿ
AtÛ  }Û  ÿÿÿÿÿÿÿ@P  ``@P  `i
ÿÿÿÿÿÿ
A€Û  ‹Û   ÿÿÿ ÿÿÿÿ@P  `l@P  `w
ÿÿÿÿÿÿ
AŸÛ  ªÛ  ışÿÿışÿÿÿCP  ‹   P  –   ÿÿÿÿÿÿ
A«Û  ³Û  ùşÿÿùşÿÿÿCP  —   P  Ÿ   
ÿÿÿÿÿÿ
A¶Û  ÁÛ  øşÿÿøşÿÿÿCP  ¢   P  ­   
ÿÿÿ	ÿÿÿ
AÜ  /Ü  õşÿÿõşÿÿÿ@S  `4@S  `I
ÿÿÿÿÿÿ
AåÜ  ùÜ  òşÿÿòşÿÿÿ@Z  `5@Z  `Iÿÿÿÿÿÿ
A%İ  /İ  ğşÿÿğşÿÿÿ@[  
@[  `
‰ÿÿÿ
A¶İ  ¿İ  íşÿÿíşÿÿÿ@c  `@c  `ÿÿÿÿÿÿ
A)Ş  /Ş  ëşÿÿëşÿÿÿ@i  `@i  `ÿÿÿ ÿÿÿ
A@Ş  HŞ  çşÿÿçşÿÿÿ@j  `@j  `
ˆOptionalş
A–Ş  Ş  åşÿÿåşÿÿÿ@o  `@o  `ÿÿÿ
ÿÿÿ
A¸Ş  ¾Ş  ãşÿÿãşÿÿÿ@q  `@q  `ÌË
Açæ  õæ  áşÿÿáşÿÿÿ@£  `,@£  `:
ƒALTş
A¾ê  Áê  âşÿÿâşÿÿÿ@¶  `@¶  `
‡CONTROLş
AÃê  Êê  ŞşÿÿŞşÿÿÿ@¶  `@¶  `
ˆMAC_METAş
AÌê  Ôê  ÚşÿÿÚşÿÿÿ@¶  `@¶  `%
„METAş
AÖê  Úê  ÖşÿÿÖşÿÿÿ@¶  `'@¶  `+
…SHIFTş
AÜê  áê  ÒşÿÿÒşÿÿÿ@¶  `-@¶  `2
ŸnormalizePassiveListenerOptionsş
AÜì  ûì  	ÔşÿÿÔşÿÿÿ@Æ  `%@Æ  `D
BehaviorSubjectş
Aò  ò  ÈşÿÿÈşÿÿÿ@ä  `@ä  `(
_getEventTargetş
A³ô  Âô  	ÌşÿÿÌşÿÿÿ@ù  `@ù  `.
üû
Aá÷  ğ÷  	ÉşÿÿÉşÿÿÿ@  `@  `.
ùø
AÀú  Ïú  	ÆşÿÿÆşÿÿÿ@$  `@$  `.
„skipş
A”û  ˜û  ¾şÿÿ¾şÿÿÿ@+  `0@+  `4
”distinctUntilChangedş
AÔû  èû  ºşÿÿºşÿÿÿ@,  `6@,  `J
ÃşÿÿÄşÿÿ
AS  ^  °şÿÿ°şÿÿÿ@K  `*@K  `5
/ÿÿÿ0ÿÿÿ
A_  j  ¸şÿÿ¸şÿÿÿ@K  `6@K  `A
½şÿÿ¾şÿÿ
Am  x  ªşÿÿªşÿÿÿ@K  `D@K  `O
Cÿÿÿ»şÿÿ
Ay  ‚  §şÿÿ§şÿÿÿ@K  `P@K  `Y
·şÿÿ¸şÿÿ
A…    ¤şÿÿ¤şÿÿÿ@K  `\@K  `gºşÿÿ¹şÿÿ
A‘  ™   şÿÿ şÿÿÿ@K  `h@K  `p
²şÿÿ³şÿÿ
Aœ  §  ŸşÿÿŸşÿÿÿ@K  `s@K  `~
¸şÿÿ°şÿÿ
Aÿ   œşÿÿœşÿÿÿ@N  `-@N  `B
¹şÿÿ­şÿÿ
A¼ Ğ ™şÿÿ™şÿÿÿ@U  `5@U  `I»şÿÿºşÿÿ
Aõ ÿ —şÿÿ—şÿÿÿ@V  
@V  `
ÿÿÿÿÿÿ
A\ g ŸşÿÿŸşÿÿÿ@\  `@\  `
-ÿÿÿ¥şÿÿ
A} † ‘şÿÿ‘şÿÿÿ@^  `@^  `·şÿÿ¶şÿÿ
AÉ Ï şÿÿşÿÿÿ@b  `@b  `¥şÿÿ¤şÿÿ
Aà è ‹şÿÿ‹şÿÿÿ@c  `@c  `¥¤
A6 > ‹şÿÿ‹şÿÿÿ@h  `@h  `±şÿÿ°şÿÿ
AX ^ ‰şÿÿ‰şÿÿÿ@j  `@j  `rÿÿÿqÿÿÿ
A¨ ¶ ‡şÿÿ‡şÿÿÿ@y  `)@y  `7pÿÿÿoÿÿÿ
A  …şÿÿ…şÿÿÿ@…  `+@…  `9
•şÿÿ–şÿÿ
A° » ‚şÿÿ‚şÿÿÿ@ñ  `"@ñ  `-
’şÿÿ“şÿÿ
AŞ é şÿÿşÿÿÿ@ñ  `P@ñ  `[
ÿÿÿşÿÿ
Aê ó |şÿÿ|şÿÿÿ@ñ  `\@ñ  `e
Œşÿÿşÿÿ
Aö  yşÿÿyşÿÿÿ@ñ  `h@ñ  `sşÿÿşÿÿ
A 
 uşÿÿuşÿÿÿ@ñ  `t@ñ  `|
‡şÿÿˆşÿÿ
A  tşÿÿtşÿÿÿ@ñ  `Añ  Š   
şÿÿ…şÿÿ
Ag | qşÿÿqşÿÿÿ@ô  `%@ô  `:
şÿÿ‚şÿÿ
A ( nşÿÿnşÿÿÿ@û  `5@û  `Işÿÿşÿÿ
AE O lşÿÿlşÿÿÿ@ü  
@ü  `„ƒ
AÚ â jşÿÿjşÿÿÿ@	  `@	  `şÿÿşÿÿ
Aü  hşÿÿhşÿÿÿ@	  `@	  `
ÿÿÿyşÿÿ
AO X eşÿÿeşÿÿÿ@
	  `@
	  `‹şÿÿŠşÿÿ
Aœ ¢ cşÿÿcşÿÿÿ@	  `@	  `yşÿÿxşÿÿ
A³ » _şÿÿ_şÿÿÿ@	  `@	  `yÿÿÿxÿÿÿ
A	  _şÿÿ_şÿÿÿ@	  `@	  `…şÿÿ„şÿÿ
A+ 1 ]şÿÿ]şÿÿÿ@	  `@	  `
ÿÿÿnşÿÿ
AF Z ZşÿÿZşÿÿÿ@T	  ` @T	  `4
ÿÿÿkşÿÿ
A[ h WşÿÿWşÿÿÿ@T	  `5@T	  `B
ÿÿÿhşÿÿ
Ak  TşÿÿTşÿÿÿ@T	  `E@T	  `Y
ÿÿÿeşÿÿ
A ¤ QşÿÿQşÿÿÿ@T	  `j@T	  `~
ContentObserver„i1$1
A¥ ¹ 
ZşÿÿZşÿÿÿ@T	  `AT	  “   
ÿÿÿ]şÿÿ
A¼ Ğ IşÿÿIşÿÿÿCT	  –   T	  ª   
âşÿÿZşÿÿ
AÑ Ú FşÿÿFşÿÿÿCT	  «   T	  ´   
ÿÿÿWşÿÿ
A  CşÿÿCşÿÿÿ@W	  `"@W	  `6
`şÿÿTşÿÿ
Aü   @şÿÿ@şÿÿÿ@a	  `5@a	  `Iÿÿÿÿÿÿ
A+  4  >şÿÿ>şÿÿÿ@b	  
@b	  `
şşÿÿOşÿÿ
A·  Ä  ;şÿÿ;şÿÿÿ@i	  `@i	  `
êë
Aı  ! 
FşÿÿFşÿÿÿ@m	  `@m	  ` 
ÑşÿÿIşÿÿ
A'! 0! 5şÿÿ5şÿÿÿ@o	  `@o	  `ÿÿÿÿÿÿ
A_! d! 3şÿÿ3şÿÿÿ@s	  `@s	  `ÿÿÿÿÿÿ
A»" É" 1şÿÿ1şÿÿÿ@ƒ	  `*@ƒ	  `8
dÿÿÿcÿÿÿ
A’# ±# 	9şÿÿ9şÿÿÿ@‰	  `$@‰	  `CZşÿÿYşÿÿ
Aq+ x+ /şÿÿ/şÿÿÿ@¾	  `*@¾	  `1
gÿÿÿfÿÿÿ
Au, „, 	4şÿÿ4şÿÿÿ@Å	  `@Å	  `$
coerceElementş
Am. z. .şÿÿ.şÿÿÿ@Õ	  `@Õ	  `'
‚ofş
A3/ 5/ $şÿÿ$şÿÿÿ@Ø	  `@Ø	  `
_getShadowRootş
A\0 j0 	(şÿÿ(şÿÿÿ@Ş	  `@Ş	  `#IşÿÿHşÿÿ
AÕ2 Ü2 şÿÿşÿÿÿ@ñ	  `@ñ	  `
òñ
A¦3 ³3 !şÿÿ!şÿÿÿ@ı	  `@ı	  `'
ïî
A5 5 şÿÿşÿÿÿ@
  `@
  `'
PÿÿÿOÿÿÿ
AMM \M 	şÿÿşÿÿÿ@š
  `@š
  `,
‰takeUntilş
AU ŠU şÿÿşÿÿÿ@×
  `8@×
  `A
şÿÿşÿÿ
A"^ -^ şÿÿşÿÿÿ@  `!@  `,
¤şÿÿşÿÿ
A.^ 7^ şÿÿşÿÿÿ@  `-@  `6
şÿÿşÿÿ
A:^ E^ şÿÿşÿÿÿ@  `9@  `D
„şÿÿ…şÿÿ
AF^ Q^ şÿÿşÿÿÿ@  `E@  `P
şÿÿşÿÿ
AT^ _^ ÿıÿÿÿıÿÿÿ@  `S@  `^
şÿÿşÿÿ
Ax^ ƒ^ üıÿÿüıÿÿÿ@  `wA  ‚   şÿÿşÿÿ
A„^ Œ^ øıÿÿøıÿÿÿC  ƒ     ‹   

şÿÿşÿÿ
A’^ ^ ÷ıÿÿ÷ıÿÿÿC  ‘     œ   
şÿÿşÿÿ
Aê^ ÿ^ ôıÿÿôıÿÿÿ@  `$@  `9
şÿÿşÿÿ
A•_ ©_ ñıÿÿñıÿÿÿ@&  `5@&  `Işÿÿşÿÿ
AÅ_ Ï_ ïıÿÿïıÿÿÿ@'  
@'  `
ˆşÿÿ şÿÿ
A,` 5` ìıÿÿìıÿÿÿ@-  `@-  `
kşÿÿlşÿÿ
AK` V` ôıÿÿôıÿÿÿ@/  `@/  `ÿÿÿ ÿÿÿ
AÅ` Í` çıÿÿçıÿÿÿ@5  `@5  `şÿÿşÿÿ
Aç` í` åıÿÿåıÿÿÿ@7  `@7  `ûıÿÿúıÿÿ
Aş` a áıÿÿáıÿÿÿ@8  `@8  `ûşÿÿúşÿÿ
ATa \a áıÿÿáıÿÿÿ@=  `@=  `şÿÿşÿÿ
Ava |a ßıÿÿßıÿÿÿ@?  `@?  `
ŒEventEmitterş
A4d @d ÛıÿÿÛıÿÿÿ@T  `@T  `*
—şÿÿìıÿÿ
Alf €f ØıÿÿØıÿÿÿ@g  `$@g  `8
˜şÿÿéıÿÿ
Af f ÕıÿÿÕıÿÿÿ@g  `9@g  `F
‘şÿÿæıÿÿ
A‘f ¥f ÒıÿÿÒıÿÿÿ@g  `I@g  `]
şÿÿãıÿÿ
Aàf ôf ÏıÿÿÏıÿÿÿ@j  `&@j  `:
ìıÿÿàıÿÿ
Aæg úg ÌıÿÿÌıÿÿÿ@s  `5@s  `I¤şÿÿ£şÿÿ
Ah "h ÊıÿÿÊıÿÿÿ@t  
@t  `
ŠşÿÿÛıÿÿ
A«h ¸h ÇıÿÿÇıÿÿÿ@z  `@z  `
†Outputş
Ai i ÃıÿÿÃıÿÿÿ@€  `@€  `
ÓıÿÿÔıÿÿ
Ay y ÀıÿÿÀıÿÿÿ@ò  `-@ò  `8
?şÿÿ@şÿÿ
Ay %y ÈıÿÿÈıÿÿÿ@ò  `9@ò  `D
ÍıÿÿÎıÿÿ
A(y 3y ºıÿÿºıÿÿÿ@ò  `G@ò  `RĞıÿÿÏıÿÿ
A4y <y ¶ıÿÿ¶ıÿÿÿ@ò  `S@ò  `[
ÑıÿÿÉıÿÿ
Aty ‰y µıÿÿµıÿÿÿ@õ  `0@õ  `E
ÒıÿÿÆıÿÿ
A7z Kz ²ıÿÿ²ıÿÿÿ@ü  `5@ü  `IÔıÿÿÓıÿÿ
Asz }z °ıÿÿ°ıÿÿÿ@ı  
@ı  `
/şÿÿ0şÿÿ
AÚz åz ¸ıÿÿ¸ıÿÿÿ@  `@  `ÓıÿÿÒıÿÿ
A){ /{ «ıÿÿ«ıÿÿÿ@  `@  `ÁıÿÿÀıÿÿ
A@{ H{ §ıÿÿ§ıÿÿÿ@  `@  `
¹ıÿÿºıÿÿ
A}  } ¦ıÿÿ¦ıÿÿÿ@  `@  `*
   ÉµÉµdefineNgModule¶ıÿÿ
Ab} u} ¢ıÿÿ¢ıÿÿÿ@!  `!@!  `4
   ÉµÉµdefineInjector²ıÿÿ
A°} Ã} ıÿÿıÿÿÿ@$  `!@$  `4
PlatformModuleş
AÓ} á} 	¥ıÿÿ¥ıÿÿÿ@%  `@%  `
ObserversModuleş
Aã} ò} `¤ıÿÿ¤ıÿÿÿ@%  `@%  `,
³ıÿÿ§ıÿÿ
A>~ R~ “ıÿÿ“ıÿÿÿ@)  `5@)  `I
ˆNgModuleş
Al~ t~ ıÿÿıÿÿÿ@*  
@*  `òñ
A“~ ¡~ 	˜ıÿÿ˜ıÿÿÿ@,  `@,  `ôó
A£~ ²~ `™ıÿÿ™ıÿÿÿ@,  ` @,  `/¹webpack/lib/dependencies/HarmonyExportSpecifierDependency@eıÿÿeıÿÿ@K   AK  ù  GıÿÿGıÿÿ@K   AK  ù  DıÿÿDıÿÿ@K   AK  ù  ?ıÿÿ?ıÿÿ@K   AK  ù  =ıÿÿ=ıÿÿ@K   AK  ù  WıÿÿWıÿÿ@K   AK  ù  ZıÿÿZıÿÿ@K   AK  ù  GıÿÿGıÿÿ@K   AK  ù  GıÿÿGıÿÿ@K   AK  ù  JıÿÿJıÿÿ@K   AK  ù  GıÿÿGıÿÿ@K   AK  ù  RıÿÿRıÿÿ@K   AK  ù  DıÿÿDıÿÿ@K   AK  ù  <ıÿÿ<ıÿÿ@K   AK  ù  QıÿÿQıÿÿ@K   AK  ù  =ıÿÿ=ıÿÿ@K   AK  ù  =ıÿÿ=ıÿÿ@K   AK  ù  SıÿÿSıÿÿ@K   AK  ù  CıÿÿCıÿÿ@K   AK  ù  AıÿÿAıÿÿ@K   AK  ù  DıÿÿDıÿÿ@K   AK  ù  6ıÿÿ6ıÿÿ@K   AK  ù  4ıÿÿ4ıÿÿ@K   AK  ù  CıÿÿCıÿÿ@K   AK  ù  AıÿÿAıÿÿ@K   AK  ù  %ıÿÿ%ıÿÿ@K   AK  ù  -ıÿÿ-ıÿÿ@K   AK  ù  @ıÿÿ@ıÿÿ@K   AK  ù  $ıÿÿ$ıÿÿ@K   AK  ù  ıÿÿıÿÿ@K   AK  ù  ıÿÿıÿÿ@K   AK  ù   `_ResolverCachePluginCacheMiss‡context„path‡request…queryˆfragment†module‰directory„fileˆinternalâüÿÿ“descriptionFilePath“descriptionFileData“descriptionFileRootŒrelativePath–__innerRequest_request›__innerRequest_relativePath__innerRequest†issuer‹issuerLayerˆcompiler2ıÿÿÌD:\GitHub\Neetechs_Frontend\node_modules\@angular\common\fesm2020\common.mjs€€ ÅD:\GitHub\Neetechs_Frontend\node_modules\@angular\common\package.json`„name‡version‹description†author‡license‡engines‡localesŒdependencies‡exportspeerDependenciesŠrepository‰ng-update‹sideEffectsˆfesm2020ˆfesm2015‡esm2020‡typingsÜ†es2020„type9ıÿÿ†13.0.1±Angular - commonly needed directives and services‡angularƒMIT„node¡^12.20.0 || ^14.15.0 || >=16.10.0ë…tslib†^2.3.0’./locales/global/*‹./locales/*./package.json.†./http./http/testing‰./testing‰./upgrade‡default•./locales/global/*.jsı./locales/*.mjsûõ…typesâä†es2015êø./common.d.ts”./esm2020/common.mjs•./fesm2020/common.mjs•./fesm2015/common.mjsÿşú./http/http.d.ts—./esm2020/http/http.mjs“./fesm2020/http.mjs“./fesm2015/http.mjsÿşõ›./http/testing/testing.d.ts¢./esm2020/http/testing/testing.mjs›./fesm2020/http/testing.mjs›./fesm2015/http/testing.mjsÿşğ–./testing/testing.d.ts./esm2020/testing/testing.mjs–./fesm2020/testing.mjs–./fesm2015/testing.mjsÿşë–./upgrade/upgrade.d.ts./esm2020/upgrade/upgrade.mjs–./fesm2020/upgrade.mjs–./fesm2015/upgrade.mjsÿşıÿÿ	ıÿÿÊ^6.5.3 || ^7.4.0Æƒurl¡ƒgit¦https://github.com/angular/angular.gitpackages/commonŒpackageGroup`üüÿÿ@angular/bazelùüÿÿ‘@angular/compiler•@angular/compiler-cli“@angular/animations‘@angular/elements™@angular/platform-browser¡@angular/platform-browser-dynamic@angular/forms˜@angular/platform-server@angular/upgrade@angular/router™@angular/language-service‘@angular/localize—@angular/service-worker**/global/*.js“**/closure-locale.*ËÌÊÉÌË‡¸D:\GitHub\Neetechs_Frontend\node_modules\@angular\commonÉÉÉ@ƒ    `RÇÚÒwBâúÿÿçúÿÿ±D:\GitHub\Neetechs_Frontend\@angular\package.json«D:\GitHub\Neetechs_Frontend\@angular\common®D:\GitHub\Neetechs_Frontend\@angular\common.ts¯D:\GitHub\Neetechs_Frontend\@angular\common.tsx¯D:\GitHub\Neetechs_Frontend\@angular\common.mjs®D:\GitHub\Neetechs_Frontend\@angular\common.js@
öÒD:\GitHub\Neetechs_Frontend\node_modules\@angular\cdk\node_modules\@angular\commonÕD:\GitHub\Neetechs_Frontend\node_modules\@angular\cdk\node_modules\@angular\common.tsÖD:\GitHub\Neetechs_Frontend\node_modules\@angular\cdk\node_modules\@angular\common.tsxÖD:\GitHub\Neetechs_Frontend\node_modules\@angular\cdk\node_modules\@angular\common.mjsÕD:\GitHub\Neetechs_Frontend\node_modules\@angular\cdk\node_modules\@angular\common.js»D:\GitHub\Neetechs_Frontend\node_modules\@angular\common.ts¼D:\GitHub\Neetechs_Frontend\node_modules\@angular\common.tsx¼D:\GitHub\Neetechs_Frontend\node_modules\@angular\common.mjs»D:\GitHub\Neetechs_Frontend\node_modules\@angular\common.js–@angular/common@13.0.1‡missingÿÿÿÿÿÿÿÿÂD:\GitHub\Neetechs_Frontend\node_modules\@angular\cdk\package.jsoné€ÁD:\GitHub\Neetechs_Frontend\node_modules\@angular\common\fesm2020`ñòóôõçö÷øùÎD:\GitHub\Neetechs_Frontend\node_modules\@angular\common\fesm2020\package.json@    “ÆÚÒwB±D:\GitHub\Neetechs_Frontend\node_modules\@angular  “ÆÚÒwB¨D:\GitHub\Neetechs_Frontend\node_modules›D:\GitHub\Neetechs_Frontend‰D:\GitHubƒD:\úúúú@   ŸüÿÿØD:\GitHub\Neetechs_Frontend\node_modules\@angular\cdk\node_modules\@angular\package.jsonÏD:\GitHub\Neetechs_Frontend\node_modules\@angular\cdk\node_modules\package.json¾D:\GitHub\Neetechs_Frontend\node_modules\@angular\node_modulesµD:\GitHub\Neetechs_Frontend\node_modules\node_modules¾D:\GitHub\Neetechs_Frontend\node_modules\@angular\package.jsonµD:\GitHub\Neetechs_Frontend\node_modules\package.jsonšüÿÿèèèèèè@   ËD:\GitHub\Neetechs_Frontend\node_modules\@angular\cdk\fesm2020\package.jsonËD:\GitHub\Neetechs_Frontend\node_modules\@angular\cdk\fesm2020\node_modulesøù@   ôõøùZÿÿÿ^ÿÿÿ‘üÿÿÈD:\GitHub\Neetechs_Frontend\node_modules\@angular\core\fesm2020\core.mjs€€ ÃD:\GitHub\Neetechs_Frontend\node_modules\@angular\core\package.json`_ÿÿÿ`ÿÿÿaÿÿÿbÿÿÿcÿÿÿdÿÿÿgÿÿÿfÿÿÿhÿÿÿiÿÿÿjÿÿÿkÿÿÿlÿÿÿmÿÿÿnÿÿÿoÿÿÿLÿÿÿpÿÿÿqÿÿÿ­üÿÿrÿÿÿœAngular - the core frameworksÿÿÿtÿÿÿuÿÿÿvÿÿÿ./schematics/*{ÿÿÿ.~ÿÿÿ€‘./schematics/*.js~ÿÿÿxÿÿÿ…‹./core.d.ts’./esm2020/core.mjs“./fesm2020/core.mjs“./fesm2015/core.mjsÿş€‘’““’kÿÿÿlÿÿÿ¡üÿÿ‡zone.js—‡~0.11.4˜™špackages/coreŠmigrationsšœ./schematics/migrations.json`•üÿÿ™“üÿÿš›œŸ ¡¢£¤¥¦ïğîíğï1ÿÿÿ¶D:\GitHub\Neetechs_Frontend\node_modules\@angular\coreííí@ƒ    `RÇÚÒwBŒúÿÿ‘úÿÿª©D:\GitHub\Neetechs_Frontend\@angular\core¬D:\GitHub\Neetechs_Frontend\@angular\core.ts­D:\GitHub\Neetechs_Frontend\@angular\core.tsx­D:\GitHub\Neetechs_Frontend\@angular\core.mjs¬D:\GitHub\Neetechs_Frontend\@angular\core.js@
÷¹D:\GitHub\Neetechs_Frontend\node_modules\@angular\core.tsºD:\GitHub\Neetechs_Frontend\node_modules\@angular\core.tsxºD:\GitHub\Neetechs_Frontend\node_modules\@angular\core.mjs¹D:\GitHub\Neetechs_Frontend\node_modules\@angular\core.jsĞD:\GitHub\Neetechs_Frontend\node_modules\@angular\cdk\node_modules\@angular\coreÓD:\GitHub\Neetechs_Frontend\node_modules\@angular\cdk\node_modules\@angular\core.tsÔD:\GitHub\Neetechs_Frontend\node_modules\@angular\cdk\node_modules\@angular\core.tsxÔD:\GitHub\Neetechs_Frontend\node_modules\@angular\cdk\node_modules\@angular\core.mjsÓD:\GitHub\Neetechs_Frontend\node_modules\@angular\cdk\node_modules\@angular\core.js”@angular/core@13.0.1«««««««««¬ìÏÎ¿D:\GitHub\Neetechs_Frontend\node_modules\@angular\core\fesm2020`÷øùúûêóôõöÌD:\GitHub\Neetechs_Frontend\node_modules\@angular\core\fesm2020\package.json·Ã¿Å ÿÿÿ$ÿÿÿWüÿÿ¿D:\GitHub\Neetechs_Frontend\node_modules\rxjs\dist\esm\index.js€€ ºD:\GitHub\Neetechs_Frontend\node_modules\rxjs\package.json`%ÿÿÿ&ÿÿÿ'ÿÿÿ„mainÿÿÿQÿÿÿPÿÿÿtypesVersions/ÿÿÿ+ÿÿÿ†config‹lint-staged‡scripts*ÿÿÿˆkeywords"ÿÿÿŒcontributors"ÿÿÿ„bugsˆhomepage#ÿÿÿdevDependencies…files…huskyjüÿÿ…7.4.0©Reactive Extensions for modern JavaScript“./dist/cjs/index.js”./dist/esm5/index.js“./dist/esm/index.jsŠindex.d.ts…>=4.2*Œdist/types/*.†./ajax‡./fetch‹./operators-ÿÿÿ‹./webSocketŒ./internal/*(ÿÿÿÿÿÿ4ÿÿÿ-ÿÿÿğòñş˜./dist/cjs/ajax/index.js˜./dist/esm/ajax/index.js™./dist/esm5/ajax/index.jsú™./dist/cjs/fetch/index.js™./dist/esm/fetch/index.jsš./dist/esm5/fetch/index.jsö./dist/cjs/operators/index.js./dist/esm/operators/index.js./dist/esm5/operators/index.jsò›./dist/cjs/testing/index.js›./dist/esm/testing/index.jsœ./dist/esm5/testing/index.jsî./dist/cjs/webSocket/index.js./dist/esm/webSocket/index.js./dist/esm5/webSocket/index.jsê˜./dist/cjs/internal/*.js˜./dist/esm/internal/*.js™./dist/esm5/internal/*.jsÿÿÿŠcommitizenÔşÿÿ™cz-conventional-changelog„*.js’(src|spec)/**/*.ts*.{js,css,md}”eslint --cache --fixŒtslint --fixprettier --writeş`‰changelog’build:spec:browser‰lint_specˆlint_src„lint‡dtslintprepublishOnlyŒpublish_docs„testˆtest:esmŒtest:browsertest:circulartest:systemjs‘test:side-effects˜test:side-effects:update‹test:import‡compile‹build:cleanŒbuild:globalbuild:package“api_guardian:updateŒapi_guardian…watchwatch:dtslint¼npx conventional-changelog-cli -p angular -i CHANGELOG.md -sğecho "Browser test is not working currently" && exit -1 && webpack --config spec/support/webpack.mocha.config.js¿tslint -c spec/tslint.json -p spec/tsconfig.json "spec/**/*.ts"½tslint -c tslint.json -p src/tsconfig.base.json "src/**/*.ts"npm-run-all --parallel lint_*ûtsc -b ./src/tsconfig.types.json && tslint -c spec-dtslint/tslint.json -p spec-dtslint/tsconfig.json "spec-dtslint/**/*.ts"–   npm run build:package && npm run lint && npm run test && npm run test:circular && npm run dtslint && npm run test:side-effects && npm run api_guardian‘./publish_docs.shÓnpm run compile && mocha --config spec/support/.mocharc.js "dist/spec/**/*-spec.js"node spec/module-test-spec.mjs‡   echo "Browser test is not working currently" && exit -1 && npm-run-all build:spec:browser && opn spec/support/mocha-browser-runner.htmlÓdependency-cruiser --validate .dependency-cruiser.json -x "^node_modules" dist/esm5¸node integration/systemjs/systemjs-compatibility-spec.jsÄcheck-side-effects --test integration/side-effects/side-effects.json¥npm run test:side-effects -- --update¦ts-node ./integration/import/runner.tsÚ   tsc -b ./src/tsconfig.cjs.json ./src/tsconfig.cjs.spec.json ./src/tsconfig.esm.json ./src/tsconfig.esm5.json ./src/tsconfig.esm5.rollup.json ./src/tsconfig.types.json ./src/tsconfig.types.spec.json ./spec/tsconfig.json‘shx rm -rf ./distÄnode ./tools/make-umd-bundle.js && node ./tools/make-closure-core.jsñnpm-run-all build:clean compile build:global && node ./tools/prepare-package.js && node ./tools/generate-alias.jsñ   tsc -b ./src/tsconfig.types.json && ts-api-guardian --outDir api_guard dist/types/index.d.ts dist/types/ajax/index.d.ts dist/types/fetch/index.d.ts dist/types/operators/index.d.ts dist/types/testing/index.d.ts dist/types/webSocket/index.d.tsĞ   ts-api-guardian --verifyDir api_guard dist/types/index.d.ts dist/types/ajax/index.d.ts dist/types/fetch/index.d.ts dist/types/operators/index.d.ts dist/types/testing/index.d.ts dist/types/webSocket/index.d.ts®nodemon -w "src/" -w "spec/" -e ts -x npm test½nodemon -w "src/" -w "spec-dtslint/" -e ts -x npm run dtslint¿şÿÿùşÿÿúşÿÿ¥https://github.com/reactivex/rxjs.git
‚Rx„RxJS‰ReactiveX’ReactiveExtensions‡Streams‹ObservablesŠObservable†StreamƒES6†ES2015šBen Lesh <ben@benlesh.com>şÿÿ…emailˆBen Leshben@benlesh.comü‹Paul Taylor”paul.e.taylor@me.comùŠJeff Cross‘crossj@google.comö’Matthew Podwysocki–matthewp@microsoft.comó‡OJ Kwon–kwon.ohjoong@gmail.comğŒAndre Staltzandre@staltz.comŠApache-2.0Ôşÿÿ¨https://github.com/ReactiveX/RxJS/issueshttps://rxjs.dev şÿÿ†~2.1.0`>Ÿ@angular-devkit/build-optimizerš@angular-devkit/schematics‹@types/chai@types/lodashŒ@types/mocha‹@types/node@types/shelljsŒ@types/sinon‘@types/sinon-chai‘@types/source-map @typescript-eslint/eslint-plugin™@typescript-eslint/parserbabel-polyfill„chai’check-side-effects…color†colors‰cross-env†’dependency-cruiser”escape-string-regexp†eslint•eslint-plugin-jasmine‰form-dataˆfs-extra„globšgoogle-closure-compiler-jsOÿÿÿ‰klaw-syncFÿÿÿ†lodashˆminimist†mkdirp…mocha‡nodemon‹npm-run-all‡opn-cliˆplatformˆprettier‡promise†rollup“rollup-plugin-alias”rollup-plugin-injectšrollup-plugin-node-resolve‡shelljsƒshx…sinonŠsinon-chai’source-map-supportˆsystemjsts-api-guardian‡ts-node†tslint–tslint-config-prettierŠtslint-etc¢tslint-no-toplevel-property-access tslint-no-unused-expression-chai‡typedocŠtypescript“validate-commit-msg”web-streams-polyfill‡webpack…0.4.6‡^11.0.7‡^4.2.11ˆ4.14.102†^7.0.2ˆ^14.14.6†^0.8.8…4.1.3†2.7.29†^0.5.2‡^4.29.1ÿ†6.26.0†^4.2.0†0.0.23…3.0.0…1.1.2…5.1.3…1.2.0‡^9.12.0…1.0.5†^7.8.1‡^2.10.1†^3.0.0†^8.1.0…7.1.2Œ20170218.0.0†^4.2.5…3.0.2ˆ^10.2.11ˆ^4.17.15†^1.2.5†^1.0.4†^8.1.3†^1.9.2…4.1.2…3.1.0…1.3.5†^2.0.5…8.0.1†0.66.6…1.4.0…2.0.0ÿ†^0.8.4†^0.3.2…4.3.0†2.14.0…0.5.3‡^0.21.0†^0.5.0†^9.0.0‡^5.20.1‡^1.18.0‡1.13.10…0.0.2…0.0.3‡^0.17.8†~4.2.2ô†^3.0.2‡^4.31.0`Œdist/bundlesœdist/cjs/**/!(*.tsbuildinfo)œdist/esm/**/!(*.tsbuildinfo)dist/esm5/**/!(*.tsbuildinfo)dist/types/**/!(*.tsbuildinfo)„ajax…fetch‰operators‡testing‰webSocketƒsrcŒCHANGELOG.md’CODE_OF_CONDUCT.md‹LICENSE.txtŒpackage.json‰README.mdtsconfig.json…hooksŠpre-commitŠcommit-msgÓşÿÿª­D:\GitHub\Neetechs_Frontend\node_modules\rxjsİşÿÿİşÿÿİşÿÿ@ƒ    `RÇÚÒwB;ùÿÿ@ùÿÿ D:\GitHub\Neetechs_Frontend\rxjs£D:\GitHub\Neetechs_Frontend\rxjs.ts¤D:\GitHub\Neetechs_Frontend\rxjs.tsx¤D:\GitHub\Neetechs_Frontend\rxjs.mjs£D:\GitHub\Neetechs_Frontend\rxjs.js `ûÿÿ÷xşÿÿyşÿÿ{şÿÿÇD:\GitHub\Neetechs_Frontend\node_modules\@angular\cdk\node_modules\rxjsvşÿÿÊD:\GitHub\Neetechs_Frontend\node_modules\@angular\cdk\node_modules\rxjs.tsËD:\GitHub\Neetechs_Frontend\node_modules\@angular\cdk\node_modules\rxjs.tsxËD:\GitHub\Neetechs_Frontend\node_modules\@angular\cdk\node_modules\rxjs.mjsÊD:\GitHub\Neetechs_Frontend\node_modules\@angular\cdk\node_modules\rxjs.js°D:\GitHub\Neetechs_Frontend\node_modules\rxjs.ts±D:\GitHub\Neetechs_Frontend\node_modules\rxjs.tsx±D:\GitHub\Neetechs_Frontend\node_modules\rxjs.mjs°D:\GitHub\Neetechs_Frontend\node_modules\rxjs.jsûÿÿŠrxjs@7.4.0ZşÿÿZşÿÿZşÿÿZşÿÿZşÿÿZşÿÿZşÿÿZşÿÿZşÿÿZşÿÿZşÿÿZşÿÿZşÿÿ·şÿÿ`kşÿÿõö÷øoşÿÿëùúûüfşÿÿ@   Yşÿÿê¶şÿÿ¶D:\GitHub\Neetechs_Frontend\node_modules\rxjs\dist\esm²D:\GitHub\Neetechs_Frontend\node_modules\rxjs\dist@   ïÃD:\GitHub\Neetechs_Frontend\node_modules\rxjs\dist\esm\package.json¿D:\GitHub\Neetechs_Frontend\node_modules\rxjs\dist\package.jsonmşÿÿÈıÿÿÌıÿÿÿúÿÿËD:\GitHub\Neetechs_Frontend\node_modules\@angular\cdk\fesm2020\keycodes.mjs€€!Kşÿÿ`ÎıÿÿÏıÿÿĞıÿÿØıÿÿ®şÿÿÒıÿÿ°şÿÿ±şÿÿÖıÿÿ×ıÿÿÕıÿÿ”optionalDependenciesŠschematics×ıÿÿØıÿÿÙıÿÿÚıÿÿÛıÿÿÜıÿÿ¹ıÿÿİıÿÿŞıÿÿŒ@angular/cdkŞıÿÿªAngular Material Component Development Kitÿÿÿşÿÿ©https://github.com/angular/components.gitİıÿÿƒcdk‰component‹developmentƒkitÙıÿÿşÿÿ¬https://github.com/angular/components/issues¬https://github.com/angular/components#readme`.“./a11y-prebuilt.css./a11y-prebuilt–./overlay-prebuilt.css’./overlay-prebuilt™./text-field-prebuilt.css•./text-field-prebuiltŒ./schematicsØıÿÿ†./a11y‹./accordion†./bidi‹./clipboardŠ./coercion./collections‹./drag-dropŠ./keycodesˆ./layout‹./observers‰./overlayŠ./platformˆ./portal‹./scrolling‰./stepper‡./tableËıÿÿ”./testing/protractorœ./testing/selenium-webdriver‘./testing/testbedŒ./text-field†./tree„sassÍıÿÿ°ıÿÿ²ıÿÿÎıÿÿ¹ıÿÿÇıÿÿ./_index.scssŒ./index.d.ts“./esm2020/index.mjs’./fesm2020/cdk.mjs’./fesm2015/cdk.mjsÿş…styleÚşÙıÚüÙûÚúÙ¹ıÿÿ•./schematics/index.js·ıÿÿ±ıÿÿ¾ıÿÿ./a11y/a11y_public_index.d.ts¤./esm2020/a11y/a11y_public_index.mjs“./fesm2020/a11y.mjs“./fesm2015/a11y.mjsÿş¹ıÿÿ§./accordion/accordion_public_index.d.ts®./esm2020/accordion/accordion_public_index.mjs˜./fesm2020/accordion.mjs˜./fesm2015/accordion.mjsÿş´ıÿÿ./bidi/bidi_public_index.d.ts¤./esm2020/bidi/bidi_public_index.mjs“./fesm2020/bidi.mjs“./fesm2015/bidi.mjsÿş¯ıÿÿ§./clipboard/clipboard_public_index.d.ts®./esm2020/clipboard/clipboard_public_index.mjs˜./fesm2020/clipboard.mjs˜./fesm2015/clipboard.mjsÿşªıÿÿ•./coercion/index.d.tsœ./esm2020/coercion/index.mjs—./fesm2020/coercion.mjs—./fesm2015/coercion.mjsÿş¥ıÿÿ«./collections/collections_public_index.d.ts²./esm2020/collections/collections_public_index.mjsš./fesm2020/collections.mjsš./fesm2015/collections.mjsÿş ıÿÿ§./drag-drop/drag-drop_public_index.d.ts®./esm2020/drag-drop/drag-drop_public_index.mjs˜./fesm2020/drag-drop.mjs˜./fesm2015/drag-drop.mjsÿş›ıÿÿ¥./keycodes/keycodes_public_index.d.ts¬./esm2020/keycodes/keycodes_public_index.mjs—./fesm2020/keycodes.mjs—./fesm2015/keycodes.mjsÿş–ıÿÿ¡./layout/layout_public_index.d.ts¨./esm2020/layout/layout_public_index.mjs•./fesm2020/layout.mjs•./fesm2015/layout.mjsÿş‘ıÿÿ§./observers/observers_public_index.d.ts®./esm2020/observers/observers_public_index.mjs˜./fesm2020/observers.mjs˜./fesm2015/observers.mjsÿşŒıÿÿ£./overlay/overlay_public_index.d.tsª./esm2020/overlay/overlay_public_index.mjs–./fesm2020/overlay.mjs–./fesm2015/overlay.mjsÿş‡ıÿÿ¥./platform/platform_public_index.d.ts¬./esm2020/platform/platform_public_index.mjs—./fesm2020/platform.mjs—./fesm2015/platform.mjsÿş‚ıÿÿ¡./portal/portal_public_index.d.ts¨./esm2020/portal/portal_public_index.mjs•./fesm2020/portal.mjs•./fesm2015/portal.mjsÿş}ıÿÿ§./scrolling/scrolling_public_index.d.ts®./esm2020/scrolling/scrolling_public_index.mjs˜./fesm2020/scrolling.mjs˜./fesm2015/scrolling.mjsÿşxıÿÿ£./stepper/stepper_public_index.d.tsª./esm2020/stepper/stepper_public_index.mjs–./fesm2020/stepper.mjs–./fesm2015/stepper.mjsÿşsıÿÿŸ./table/table_public_index.d.ts¦./esm2020/table/table_public_index.mjs”./fesm2020/table.mjs”./fesm2015/table.mjsÿşnıÿÿ”./testing/index.d.ts›./esm2020/testing/index.mjs~ıÿÿıÿÿıÿÿ~ıÿÿkıÿÿŸ./testing/protractor/index.d.ts¦./esm2020/testing/protractor/index.mjs¡./fesm2020/testing/protractor.mjs¡./fesm2015/testing/protractor.mjsÿşfıÿÿ§./testing/selenium-webdriver/index.d.ts®./esm2020/testing/selenium-webdriver/index.mjs©./fesm2020/testing/selenium-webdriver.mjs©./fesm2015/testing/selenium-webdriver.mjsÿşaıÿÿœ./testing/testbed/index.d.ts£./esm2020/testing/testbed/index.mjs./fesm2020/testing/testbed.mjs./fesm2015/testing/testbed.mjsÿş\ıÿÿ©./text-field/text-field_public_index.d.ts°./esm2020/text-field/text-field_public_index.mjs™./fesm2020/text-field.mjs™./fesm2015/text-field.mjsÿşWıÿÿ./tree/tree_public_index.d.ts¤./esm2020/tree/tree_public_index.mjs“./fesm2020/tree.mjs“./fesm2015/tree.mjsÿşrúÿÿpúÿÿuúÿÿ”^13.0.0 || ^14.0.0-0ÿkıÿÿ;ıÿÿ<ıÿÿ†parse5†^5.0.0œ./schematics/collection.jsonÒıÿÿ›./schematics/migration.json|ÿÿÿ}ÿÿÿ{ÿÿÿzÿÿÿ}ÿÿÿ|ÿÿÿıÿÿDúÿÿ­­­@    `RÇÚÒwBCúÿÿDúÿÿGÿÿÿªıÿÿ ıÿÿ@   @úÿÿ‘ıÿÿæùÿÿıÿÿıÿÿ>úÿÿÉD:\GitHub\Neetechs_Frontend\node_modules\rxjs\dist\esm\operators\index.js€€ çıÿÿÿÿÿÿÿÿşÿÿşÿÿşÿÿ@    `RÇÚÒwBÿÿÿ7úÿÿÿÿÿšıÿÿ›ıÿÿ"ÿÿÿ8úÿÿ+ÿÿÿ†ıÿÿ†ıÿÿ†ıÿÿüÀD:\GitHub\Neetechs_Frontend\node_modules\rxjs\dist\esm\operatorsÍD:\GitHub\Neetechs_Frontend\node_modules\rxjs\dist\esm\operators\package.jsonıÿÿ-ÿÿÿ2ÿÿÿûüÿÿÿüÿÿ2úÿÿËD:\GitHub\Neetechs_Frontend\node_modules\@angular\cdk\fesm2020\coercion.mjs€€!~ıÿÿè-úÿÿ‡‡‡@    `RÇÚÒwB,úÿÿ-úÿÿı“ıÿÿ‰ıÿÿêòüÿÿöüÿÿ)úÿÿËD:\GitHub\Neetechs_Frontend\node_modules\@angular\cdk\fesm2020\platform.mjs€€!uıÿÿß$úÿÿ¡¡¡@    `RÇÚÒwB#úÿÿ$úÿÿıŠıÿÿ€ıÿÿáéüÿÿíüÿÿ úÿÿÌD:\GitHub\Neetechs_Frontend\node_modules\@angular\cdk\fesm2020\observers.mjs€€!lıÿÿÖúÿÿ@    `RÇÚÒwBúÿÿúÿÿııÿÿwıÿÿØ
«webpack/lib/util/registerExternalSerializerwebpack-sources/OriginalSource+  /**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */
const MAC_ENTER = 3;
const BACKSPACE = 8;
const TAB = 9;
const NUM_CENTER = 12;
const ENTER = 13;
const SHIFT = 16;
const CONTROL = 17;
const ALT = 18;
const PAUSE = 19;
const CAPS_LOCK = 20;
const ESCAPE = 27;
const SPACE = 32;
const PAGE_UP = 33;
const PAGE_DOWN = 34;
const END = 35;
const HOME = 36;
const LEFT_ARROW = 37;
const UP_ARROW = 38;
const RIGHT_ARROW = 39;
const DOWN_ARROW = 40;
const PLUS_SIGN = 43;
const PRINT_SCREEN = 44;
const INSERT = 45;
const DELETE = 46;
const ZERO = 48;
const ONE = 49;
const TWO = 50;
const THREE = 51;
const FOUR = 52;
const FIVE = 53;
const SIX = 54;
const SEVEN = 55;
const EIGHT = 56;
const NINE = 57;
const FF_SEMICOLON = 59; // Firefox (Gecko) fires this for semicolon instead of 186
const FF_EQUALS = 61; // Firefox (Gecko) fires this for equals instead of 187
const QUESTION_MARK = 63;
const AT_SIGN = 64;
const A = 65;
const B = 66;
const C = 67;
const D = 68;
const E = 69;
const F = 70;
const G = 71;
const H = 72;
const I = 73;
const J = 74;
const K = 75;
const L = 76;
const M = 77;
const N = 78;
const O = 79;
const P = 80;
const Q = 81;
const R = 82;
const S = 83;
const T = 84;
const U = 85;
const V = 86;
const W = 87;
const X = 88;
const Y = 89;
const Z = 90;
const META = 91; // WIN_KEY_LEFT
const MAC_WK_CMD_LEFT = 91;
const MAC_WK_CMD_RIGHT = 93;
const CONTEXT_MENU = 93;
const NUMPAD_ZERO = 96;
const NUMPAD_ONE = 97;
const NUMPAD_TWO = 98;
const NUMPAD_THREE = 99;
const NUMPAD_FOUR = 100;
const NUMPAD_FIVE = 101;
const NUMPAD_SIX = 102;
const NUMPAD_SEVEN = 103;
const NUMPAD_EIGHT = 104;
const NUMPAD_NINE = 105;
const NUMPAD_MULTIPLY = 106;
const NUMPAD_PLUS = 107;
const NUMPAD_MINUS = 109;
const NUMPAD_PERIOD = 110;
const NUMPAD_DIVIDE = 111;
const F1 = 112;
const F2 = 113;
const F3 = 114;
const F4 = 115;
const F5 = 116;
const F6 = 117;
const F7 = 118;
const F8 = 119;
const F9 = 120;
const F10 = 121;
const F11 = 122;
const F12 = 123;
const NUM_LOCK = 144;
const SCROLL_LOCK = 145;
const FIRST_MEDIA = 166;
const FF_MINUS = 173;
const MUTE = 173; // Firefox (Gecko) fires 181 for MUTE
const VOLUME_DOWN = 174; // Firefox (Gecko) fires 182 for VOLUME_DOWN
const VOLUME_UP = 175; // Firefox (Gecko) fires 183 for VOLUME_UP
const FF_MUTE = 181;
const FF_VOLUME_DOWN = 182;
const LAST_MEDIA = 183;
const FF_VOLUME_UP = 183;
const SEMICOLON = 186; // Firefox (Gecko) fires 59 for SEMICOLON
const EQUALS = 187; // Firefox (Gecko) fires 61 for EQUALS
const COMMA = 188;
const DASH = 189; // Firefox (Gecko) fires 173 for DASH/MINUS
const PERIOD = 190;
const SLASH = 191;
const APOSTROPHE = 192;
const TILDE = 192;
const OPEN_SQUARE_BRACKET = 219;
const BACKSLASH = 220;
const CLOSE_SQUARE_BRACKET = 221;
const SINGLE_QUOTE = 222;
const MAC_META = 224;

/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */
/**
 * Checks whether a modifier key is pressed.
 * @param event Event to be checked.
 */
function hasModifierKey(event, ...modifiers) {
    if (modifiers.length) {
        return modifiers.some(modifier => event[modifier]);
    }
    return event.altKey || event.shiftKey || event.ctrlKey || event.metaKey;
}

/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

/**
 * Generated bundle index. Do not edit.
 */

export { A, ALT, APOSTROPHE, AT_SIGN, B, BACKSLASH, BACKSPACE, C, CAPS_LOCK, CLOSE_SQUARE_BRACKET, COMMA, CONTEXT_MENU, CONTROL, D, DASH, DELETE, DOWN_ARROW, E, EIGHT, END, ENTER, EQUALS, ESCAPE, F, F1, F10, F11, F12, F2, F3, F4, F5, F6, F7, F8, F9, FF_EQUALS, FF_MINUS, FF_MUTE, FF_SEMICOLON, FF_VOLUME_DOWN, FF_VOLUME_UP, FIRST_MEDIA, FIVE, FOUR, G, H, HOME, I, INSERT, J, K, L, LAST_MEDIA, LEFT_ARROW, M, MAC_ENTER, MAC_META, MAC_WK_CMD_LEFT, MAC_WK_CMD_RIGHT, META, MUTE, N, NINE, NUMPAD_DIVIDE, NUMPAD_EIGHT, NUMPAD_FIVE, NUMPAD_FOUR, NUMPAD_MINUS, NUMPAD_MULTIPLY, NUMPAD_NINE, NUMPAD_ONE, NUMPAD_PERIOD, NUMPAD_PLUS, NUMPAD_SEVEN, NUMPAD_SIX, NUMPAD_THREE, NUMPAD_TWO, NUMPAD_ZERO, NUM_CENTER, NUM_LOCK, O, ONE, OPEN_SQUARE_BRACKET, P, PAGE_DOWN, PAGE_UP, PAUSE, PERIOD, PLUS_SIGN, PRINT_SCREEN, Q, QUESTION_MARK, R, RIGHT_ARROW, S, SCROLL_LOCK, SEMICOLON, SEVEN, SHIFT, SINGLE_QUOTE, SIX, SLASH, SPACE, T, TAB, THREE, TILDE, TWO, U, UP_ARROW, V, VOLUME_DOWN, VOLUME_UP, W, X, Y, Z, ZERO, hasModifierKey };
ñ   webpack://javascript/esm|./node_modules/@angular-devkit/build-angular/src/babel/webpack-loader.js??ruleSet[1].rules[1].use[0]!./node_modules/source-map-loader/dist/cjs.js??ruleSet[1].rules[2]!./node_modules/@angular/cdk/fesm2020/keycodes.mjs`³ùÿÿ´ùÿÿµùÿÿ@¶ùÿÿ¸ùÿÿ¹ùÿÿşÉùÿÿ	ÊùÿÿËùÿÿÌùÿÿÍùÿÿf9d51a4c976d3b2dÎùÿÿÏùÿÿ`x˜úÿÿ‰MAC_ENTER‰BACKSPACEzúÿÿŠNUM_CENTER…ENTER[ûÿÿOûÿÿKûÿÿ…PAUSE‰CAPS_LOCK†ESCAPE…SPACE‡PAGE_UP‰PAGE_DOWNŠúÿÿ†úÿÿ‚úÿÿzúÿÿ~úÿÿvúÿÿ‰PLUS_SIGNŒPRINT_SCREEN†INSERT†DELETE”úÿÿƒONEƒTWO…THREE„FOUR„FIVEƒSIX…SEVEN…EIGHTúÿÿŒFF_SEMICOLON‰FF_EQUALSQUESTION_MARK‡AT_SIGNABCDEFGHIJKLMNOPQRSTUVWXYZAûÿÿMAC_WK_CMD_LEFTMAC_WK_CMD_RIGHTŒCONTEXT_MENU‹NUMPAD_ZEROŠNUMPAD_ONEŠNUMPAD_TWOŒNUMPAD_THREE‹NUMPAD_FOUR‹NUMPAD_FIVEŠNUMPAD_SIXŒNUMPAD_SEVENŒNUMPAD_EIGHT‹NUMPAD_NINENUMPAD_MULTIPLY‹NUMPAD_PLUSŒNUMPAD_MINUSNUMPAD_PERIODNUMPAD_DIVIDE‚F1‚F2‚F3‚F4‚F5‚F6‚F7‚F8‚F9ƒF10ƒF11ƒF12ˆNUM_LOCK‹SCROLL_LOCK‹FIRST_MEDIAˆFF_MINUS„MUTE‹VOLUME_DOWN‰VOLUME_UP‡FF_MUTEFF_VOLUME_DOWNŠLAST_MEDIAŒFF_VOLUME_UP‰SEMICOLON†EQUALS…COMMA„DASH†PERIOD…SLASHŠAPOSTROPHE…TILDE“OPEN_SQUARE_BRACKET‰BACKSLASH”CLOSE_SQUARE_BRACKETŒSINGLE_QUOTEûÿÿ@    ğÆÚÒwB¼ùÿÿ½ùÿÿÀşÿÿdÿ ÿ ıaA5  *  @¦    A¦   õ  `xAA@¦    A¦   õ  öúÿÿöúÿÿ@¦    A¦   õ  ïï@¦    A¦   õ  ¾¾@¦    A¦   õ  BB@¦    A¦   õ  ïï@¦    A¦   õ  ££@¦    A¦   õ  CC@¦    A¦   õ  ¥¥@¦    A¦   õ  ìì@¦    A¦   õ  ãã@¦    A¦   õ  ¹¹@¦    A¦   õ  ïúÿÿïúÿÿ@¦    A¦   õ  DD@¦    A¦   õ  àà@¦    A¦   õ  ¦¦@¦    A¦   õ  úÿÿúÿÿ@¦    A¦   õ  EE@¦    A¦   õ  ««@¦    A¦   õ  )úÿÿ)úÿÿ@¦    A¦   õ  ——@¦    A¦   õ  ××@¦    A¦   õ  ˜˜@¦    A¦   õ  FF@¦    A¦   õ  ¼¼@¦    A¦   õ  ÄÄ@¦    A¦   õ  ÄÄ@¦    A¦   õ  ÄÄ@¦    A¦   õ  ¹¹@¦    A¦   õ  ¹¹@¦    A¦   õ  ¹¹@¦    A¦   õ  ¹¹@¦    A¦   õ  ¹¹@¦    A¦   õ  ¹¹@¦    A¦   õ  ¹¹@¦    A¦   õ  ¹¹@¦    A¦   õ  ››@¦    A¦   õ  ¾¾@¦    A¦   õ  ÁÁ@¦    A¦   õ  ——@¦    A¦   õ  ÀÀ@¦    A¦   õ  ÁÁ@¦    A¦   õ  ¸¸@¦    A¦   õ  @¦    A¦   õ  @¦    A¦   õ  GG@¦    A¦   õ  HH@¦    A¦   õ  	úÿÿ	úÿÿ@¦    A¦   õ  II@¦    A¦   õ  ƒƒ@¦    A¦   õ  JJ@¦    A¦   õ  KK@¦    A¦   õ  LL@¦    A¦   õ  ´´@¦    A¦   õ  şùÿÿşùÿÿ@¦    A¦   õ  MM@¦    A¦   õ  pÿÿÿpÿÿÿ@¦    A¦   õ  ÆúÿÿÆúÿÿ@¦    A¦   õ  ˆˆ@¦    A¦   õ  ˆˆ@¦    A¦   õ  ÇúÿÿÇúÿÿ@¦    A¦   õ  §§@¦    A¦   õ  NN@¦    A¦   õ  úÿÿúÿÿ@¦    A¦   õ  ““@¦    A¦   õ  ŒŒ@¦    A¦   õ  ˆˆ@¦    A¦   õ  ††@¦    A¦   õ  @¦    A¦   õ  ŠŠ@¦    A¦   õ  ˆˆ@¦    A¦   õ  ÿÿÿÿÿÿ@¦    A¦   õ  ŠŠ@¦    A¦   õ  ‡‡@¦    A¦   õ  ‚‚@¦    A¦   õ  €€@¦    A¦   õ  |ÿÿÿ|ÿÿÿ@¦    A¦   õ  zÿÿÿzÿÿÿ@¦    A¦   õ  wÿÿÿwÿÿÿ@¦    A¦   õ  [ÿÿÿ[ÿÿÿ@¦    A¦   õ  @¦    A¦   õ  OO@¦    A¦   õ  dÿÿÿdÿÿÿ@¦    A¦   õ    @¦    A¦   õ  PP@¦    A¦   õ  \ÿÿÿ\ÿÿÿ@¦    A¦   õ  ZÿÿÿZÿÿÿ@¦    A¦   õ  UÿÿÿUÿÿÿ@¦    A¦   õ  ——@¦    A¦   õ  YÿÿÿYÿÿÿ@¦    A¦   õ  YÿÿÿYÿÿÿ@¦    A¦   õ  QQ@¦    A¦   õ  dÿÿÿdÿÿÿ@¦    A¦   õ  RR@¦    A¦   õ  ÒùÿÿÒùÿÿ@¦    A¦   õ  SS@¦    A¦   õ  @¦    A¦   õ  ŠŠ@¦    A¦   õ  ZÿÿÿZÿÿÿ@¦    A¦   õ  ¤úÿÿ¤úÿÿ@¦    A¦   õ  ’’@¦    A¦   õ  VÿÿÿVÿÿÿ@¦    A¦   õ  ŠŠ@¦    A¦   õ  HÿÿÿHÿÿÿ@¦    A¦   õ  TT@¦    A¦   õ  »ùÿÿ»ùÿÿ@¦    A¦   õ  NÿÿÿNÿÿÿ@¦    A¦   õ  ‡‡@¦    A¦   õ  KÿÿÿKÿÿÿ@¦    A¦   õ  UU@¦    A¦   õ  ¾ùÿÿ¾ùÿÿ@¦    A¦   õ  VV@¦    A¦   õ  uÿÿÿuÿÿÿ@¦    A¦   õ  uÿÿÿuÿÿÿ@¦    A¦   õ  WW@¦    A¦   õ  XX@¦    A¦   õ  YY@¦    A¦   õ  ZZ@¦    A¦   õ  ÔùÿÿÔùÿÿ@¦    A¦   õ  ÉùÿÿÉùÿÿ@¦    A¦   õ   ´  import { ElementRef } from '@angular/core';

/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */
/** Coerces a data-bound value (typically a string) to a boolean. */
function coerceBooleanProperty(value) {
    return value != null && `${value}` !== 'false';
}

/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */
function coerceNumberProperty(value, fallbackValue = 0) {
    return _isNumberValue(value) ? Number(value) : fallbackValue;
}
/**
 * Whether the provided value is considered a number.
 * @docs-private
 */
function _isNumberValue(value) {
    // parseFloat(value) handles most of the cases we're interested in (it treats null, empty string,
    // and other non-number values as NaN, where Number just uses 0) but it considers the string
    // '123hello' to be a valid number. Therefore we also check if Number(value) is NaN.
    return !isNaN(parseFloat(value)) && !isNaN(Number(value));
}

/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */
function coerceArray(value) {
    return Array.isArray(value) ? value : [value];
}

/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */
/** Coerces a value to a CSS pixel value. */
function coerceCssPixelValue(value) {
    if (value == null) {
        return '';
    }
    return typeof value === 'string' ? value : `${value}px`;
}

/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */
/**
 * Coerces an ElementRef or an Element into an element.
 * Useful for APIs that can accept either a ref or the native element itself.
 */
function coerceElement(elementOrRef) {
    return elementOrRef instanceof ElementRef ? elementOrRef.nativeElement : elementOrRef;
}

/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */
/**
 * Coerces a value to an array of trimmed non-empty strings.
 * Any input that is not an array, `null` or `undefined` will be turned into a string
 * via `toString()` and subsequently split with the given separator.
 * `null` and `undefined` will result in an empty array.
 * This results in the following outcomes:
 * - `null` -&gt; `[]`
 * - `[null]` -&gt; `["null"]`
 * - `["a", "b ", " "]` -&gt; `["a", "b"]`
 * - `[1, [2, 3]]` -&gt; `["1", "2,3"]`
 * - `[{ a: 0 }]` -&gt; `["[object Object]"]`
 * - `{ a: 0 }` -&gt; `["[object", "Object]"]`
 *
 * Useful for defining CSS classes or table columns.
 * @param value the value to coerce into an array of strings
 * @param separator split-separator if value isn't an array
 */
function coerceStringArray(value, separator = /\s+/) {
    const result = [];
    if (value != null) {
        const sourceValues = Array.isArray(value) ? value : `${value}`.split(separator);
        for (const sourceValue of sourceValues) {
            const trimmedString = `${sourceValue}`.trim();
            if (trimmedString) {
                result.push(trimmedString);
            }
        }
    }
    return result;
}

/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

export { _isNumberValue, coerceArray, coerceBooleanProperty, coerceCssPixelValue, coerceElement, coerceNumberProperty, coerceStringArray };
ñ   webpack://javascript/esm|./node_modules/@angular-devkit/build-angular/src/babel/webpack-loader.js??ruleSet[1].rules[1].use[0]!./node_modules/source-map-loader/dist/cjs.js??ruleSet[1].rules[2]!./node_modules/@angular/cdk/fesm2020/coercion.mjs`ØøÿÿÙøÿÿÚøÿÿ@ÛøÿÿİøÿÿŞøÿÿşîøÿÿ	ïøÿÿğøÿÿñøÿÿòøÿÿ64df0001cd994cebóøÿÿôøÿÿúÿÿ”coerceNumberProperty_isNumberValue‹coerceArray“coerceCssPixelValue(ûÿÿ‘coerceStringArray@    ğÆÚÒwB+ùÿÿ,ùÿÿüşÿÿdÿ ÿ ı€ `+ `+aA(  ³  @ƒ    Aƒ   ‹   	DùÿÿDùÿÿ `+úÿÿúÿÿA	  	  AùÿÿAùÿÿÿcJ#J-íí@ƒ    Aƒ   ‹   íí@ƒ    Aƒ   ‹   ğùÿÿğùÿÿ@ƒ    Aƒ   ‹   ìì@ƒ    Aƒ   ‹   ûÿÿûÿÿ@ƒ    Aƒ   ‹   çç@ƒ    Aƒ   ‹   êê@ƒ    Aƒ   ‹    
Ï<  import * as i0 from '@angular/core';
import { PLATFORM_ID, Injectable, Inject, NgModule } from '@angular/core';
import { isPlatformBrowser } from '@angular/common';
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */
// Whether the current platform supports the V8 Break Iterator. The V8 check
// is necessary to detect all Blink based browsers.

let hasV8BreakIterator; // We need a try/catch around the reference to `Intl`, because accessing it in some cases can
// cause IE to throw. These cases are tied to particular versions of Windows and can happen if
// the consumer is providing a polyfilled `Map`. See:
// https://github.com/Microsoft/ChakraCore/issues/3189
// https://github.com/angular/components/issues/15687

try {
  hasV8BreakIterator = typeof Intl !== 'undefined' && Intl.v8BreakIterator;
} catch {
  hasV8BreakIterator = false;
}
/**
 * Service to detect the current platform by comparing the userAgent strings and
 * checking browser-specific global properties.
 */


class Platform {
  constructor(_platformId) {
    this._platformId = _platformId; // We want to use the Angular platform check because if the Document is shimmed
    // without the navigator, the following checks will fail. This is preferred because
    // sometimes the Document may be shimmed without the user's knowledge or intention

    /** Whether the Angular application is being rendered in the browser. */

    this.isBrowser = this._platformId ? isPlatformBrowser(this._platformId) : typeof document === 'object' && !!document;
    /** Whether the current browser is Microsoft Edge. */

    this.EDGE = this.isBrowser && /(edge)/i.test(navigator.userAgent);
    /** Whether the current rendering engine is Microsoft Trident. */

    this.TRIDENT = this.isBrowser && /(msie|trident)/i.test(navigator.userAgent); // EdgeHTML and Trident mock Blink specific things and need to be excluded from this check.

    /** Whether the current rendering engine is Blink. */

    this.BLINK = this.isBrowser && !!(window.chrome || hasV8BreakIterator) && typeof CSS !== 'undefined' && !this.EDGE && !this.TRIDENT; // Webkit is part of the userAgent in EdgeHTML, Blink and Trident. Therefore we need to
    // ensure that Webkit runs standalone and is not used as another engine's base.

    /** Whether the current rendering engine is WebKit. */

    this.WEBKIT = this.isBrowser && /AppleWebKit/i.test(navigator.userAgent) && !this.BLINK && !this.EDGE && !this.TRIDENT;
    /** Whether the current platform is Apple iOS. */

    this.IOS = this.isBrowser && /iPad|iPhone|iPod/.test(navigator.userAgent) && !('MSStream' in window); // It's difficult to detect the plain Gecko engine, because most of the browsers identify
    // them self as Gecko-like browsers and modify the userAgent's according to that.
    // Since we only cover one explicit Firefox case, we can simply check for Firefox
    // instead of having an unstable check for Gecko.

    /** Whether the current browser is Firefox. */

    this.FIREFOX = this.isBrowser && /(firefox|minefield)/i.test(navigator.userAgent);
    /** Whether the current platform is Android. */
    // Trident on mobile adds the android platform to the userAgent to trick detections.

    this.ANDROID = this.isBrowser && /android/i.test(navigator.userAgent) && !this.TRIDENT; // Safari browsers will include the Safari keyword in their userAgent. Some browsers may fake
    // this and just place the Safari keyword in the userAgent. To be more safe about Safari every
    // Safari browser should also use Webkit as its layout engine.

    /** Whether the current browser is Safari. */

    this.SAFARI = this.isBrowser && /safari/i.test(navigator.userAgent) && this.WEBKIT;
  }

}

Platform.Éµfac = function Platform_Factory(t) {
  return new (t || Platform)(i0.ÉµÉµinject(PLATFORM_ID));
};

Platform.Éµprov = /* @__PURE__ */i0.ÉµÉµdefineInjectable({
  token: Platform,
  factory: Platform.Éµfac,
  providedIn: 'root'
});

(function () {
  (typeof ngDevMode === "undefined" || ngDevMode) && i0.ÉµsetClassMetadata(Platform, [{
    type: Injectable,
    args: [{
      providedIn: 'root'
    }]
  }], function () {
    return [{
      type: Object,
      decorators: [{
        type: Inject,
        args: [PLATFORM_ID]
      }]
    }];
  }, null);
})();
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */


class PlatformModule {}

PlatformModule.Éµfac = function PlatformModule_Factory(t) {
  return new (t || PlatformModule)();
};

PlatformModule.Éµmod = /* @__PURE__ */i0.ÉµÉµdefineNgModule({
  type: PlatformModule
});
PlatformModule.Éµinj = /* @__PURE__ */i0.ÉµÉµdefineInjector({});

(function () {
  (typeof ngDevMode === "undefined" || ngDevMode) && i0.ÉµsetClassMetadata(PlatformModule, [{
    type: NgModule,
    args: [{}]
  }], null, null);
})();
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

/** Cached result Set of input types support by the current browser. */


let supportedInputTypes;
/** Types of `<input>` that *might* be supported. */

const candidateInputTypes = [// `color` must come first. Chrome 56 shows a warning if we change the type to `color` after
// first changing it to something else:
// The specified value "" does not conform to the required format.
// The format is "#rrggbb" where rr, gg, bb are two-digit hexadecimal numbers.
'color', 'button', 'checkbox', 'date', 'datetime-local', 'email', 'file', 'hidden', 'image', 'month', 'number', 'password', 'radio', 'range', 'reset', 'search', 'submit', 'tel', 'text', 'time', 'url', 'week'];
/** @returns The input types supported by this browser. */

function getSupportedInputTypes() {
  // Result is cached.
  if (supportedInputTypes) {
    return supportedInputTypes;
  } // We can't check if an input type is not supported until we're on the browser, so say that
  // everything is supported when not on the browser. We don't use `Platform` here since it's
  // just a helper function and can't inject it.


  if (typeof document !== 'object' || !document) {
    supportedInputTypes = new Set(candidateInputTypes);
    return supportedInputTypes;
  }

  let featureTestInput = document.createElement('input');
  supportedInputTypes = new Set(candidateInputTypes.filter(value => {
    featureTestInput.setAttribute('type', value);
    return featureTestInput.type === value;
  }));
  return supportedInputTypes;
}
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

/** Cached result of whether the user's browser supports passive event listeners. */


let supportsPassiveEvents;
/**
 * Checks whether the user's browser supports passive event listeners.
 * See: https://github.com/WICG/EventListenerOptions/blob/gh-pages/explainer.md
 */

function supportsPassiveEventListeners() {
  if (supportsPassiveEvents == null && typeof window !== 'undefined') {
    try {
      window.addEventListener('test', null, Object.defineProperty({}, 'passive', {
        get: () => supportsPassiveEvents = true
      }));
    } finally {
      supportsPassiveEvents = supportsPassiveEvents || false;
    }
  }

  return supportsPassiveEvents;
}
/**
 * Normalizes an `AddEventListener` object to something that can be passed
 * to `addEventListener` on any browser, no matter whether it supports the
 * `options` parameter.
 * @param options Object to be normalized.
 */


function normalizePassiveListenerOptions(options) {
  return supportsPassiveEventListeners() ? options : !!options.capture;
}
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

/** Cached result of the way the browser handles the horizontal scroll axis in RTL mode. */


let rtlScrollAxisType;
/** Cached result of the check that indicates whether the browser supports scroll behaviors. */

let scrollBehaviorSupported;
/** Check whether the browser supports scroll behaviors. */

function supportsScrollBehavior() {
  if (scrollBehaviorSupported == null) {
    // If we're not in the browser, it can't be supported. Also check for `Element`, because
    // some projects stub out the global `document` during SSR which can throw us off.
    if (typeof document !== 'object' || !document || typeof Element !== 'function' || !Element) {
      scrollBehaviorSupported = false;
      return scrollBehaviorSupported;
    } // If the element can have a `scrollBehavior` style, we can be sure that it's supported.


    if ('scrollBehavior' in document.documentElement.style) {
      scrollBehaviorSupported = true;
    } else {
      // At this point we have 3 possibilities: `scrollTo` isn't supported at all, it's
      // supported but it doesn't handle scroll behavior, or it has been polyfilled.
      const scrollToFunction = Element.prototype.scrollTo;

      if (scrollToFunction) {
        // We can detect if the function has been polyfilled by calling `toString` on it. Native
        // functions are obfuscated using `[native code]`, whereas if it was overwritten we'd get
        // the actual function source. Via https://davidwalsh.name/detect-native-function. Consider
        // polyfilled functions as supporting scroll behavior.
        scrollBehaviorSupported = !/\{\s*\[native code\]\s*\}/.test(scrollToFunction.toString());
      } else {
        scrollBehaviorSupported = false;
      }
    }
  }

  return scrollBehaviorSupported;
}
/**
 * Checks the type of RTL scroll axis used by this browser. As of time of writing, Chrome is NORMAL,
 * Firefox & Safari are NEGATED, and IE & Edge are INVERTED.
 */


function getRtlScrollAxisType() {
  // We can't check unless we're on the browser. Just assume 'normal' if we're not.
  if (typeof document !== 'object' || !document) {
    return 0
    /* NORMAL */
    ;
  }

  if (rtlScrollAxisType == null) {
    // Create a 1px wide scrolling container and a 2px wide content element.
    const scrollContainer = document.createElement('div');
    const containerStyle = scrollContainer.style;
    scrollContainer.dir = 'rtl';
    containerStyle.width = '1px';
    containerStyle.overflow = 'auto';
    containerStyle.visibility = 'hidden';
    containerStyle.pointerEvents = 'none';
    containerStyle.position = 'absolute';
    const content = document.createElement('div');
    const contentStyle = content.style;
    contentStyle.width = '2px';
    contentStyle.height = '1px';
    scrollContainer.appendChild(content);
    document.body.appendChild(scrollContainer);
    rtlScrollAxisType = 0
    /* NORMAL */
    ; // The viewport starts scrolled all the way to the right in RTL mode. If we are in a NORMAL
    // browser this would mean that the scrollLeft should be 1. If it's zero instead we know we're
    // dealing with one of the other two types of browsers.

    if (scrollContainer.scrollLeft === 0) {
      // In a NEGATED browser the scrollLeft is always somewhere in [-maxScrollAmount, 0]. For an
      // INVERTED browser it is always somewhere in [0, maxScrollAmount]. We can determine which by
      // setting to the scrollLeft to 1. This is past the max for a NEGATED browser, so it will
      // return 0 when we read it again.
      scrollContainer.scrollLeft = 1;
      rtlScrollAxisType = scrollContainer.scrollLeft === 0 ? 1
      /* NEGATED */
      : 2
      /* INVERTED */
      ;
    }

    scrollContainer.remove();
  }

  return rtlScrollAxisType;
}
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */


let shadowDomIsSupported;
/** Checks whether the user's browser support Shadow DOM. */

function _supportsShadowDom() {
  if (shadowDomIsSupported == null) {
    const head = typeof document !== 'undefined' ? document.head : null;
    shadowDomIsSupported = !!(head && (head.createShadowRoot || head.attachShadow));
  }

  return shadowDomIsSupported;
}
/** Gets the shadow root of an element, if supported and the element is inside the Shadow DOM. */


function _getShadowRoot(element) {
  if (_supportsShadowDom()) {
    const rootNode = element.getRootNode ? element.getRootNode() : null; // Note that this should be caught by `_supportsShadowDom`, but some
    // teams have been able to hit this code path on unsupported browsers.

    if (typeof ShadowRoot !== 'undefined' && ShadowRoot && rootNode instanceof ShadowRoot) {
      return rootNode;
    }
  }

  return null;
}
/**
 * Gets the currently-focused element on the page while
 * also piercing through Shadow DOM boundaries.
 */


function _getFocusedElementPierceShadowDom() {
  let activeElement = typeof document !== 'undefined' && document ? document.activeElement : null;

  while (activeElement && activeElement.shadowRoot) {
    const newActiveElement = activeElement.shadowRoot.activeElement;

    if (newActiveElement === activeElement) {
      break;
    } else {
      activeElement = newActiveElement;
    }
  }

  return activeElement;
}
/** Gets the target of an event while accounting for Shadow DOM. */


function _getEventTarget(event) {
  // If an event is bound outside the Shadow DOM, the `event.target` will
  // point to the shadow root so we have to use `composedPath` instead.
  return event.composedPath ? event.composedPath()[0] : event.target;
}
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

/** Gets whether the code is currently running in a test environment. */


function _isTestEnvironment() {
  // We can't use `declare const` because it causes conflicts inside Google with the real typings
  // for these symbols and we can't read them off the global object, because they don't appear to
  // be attached there for some runners like Jest.
  // (see: https://github.com/angular/components/issues/23365#issuecomment-938146643)
  return (// @ts-ignore
    typeof __karma__ !== 'undefined' && !!__karma__ || // @ts-ignore
    typeof jasmine !== 'undefined' && !!jasmine || // @ts-ignore
    typeof jest !== 'undefined' && !!jest || // @ts-ignore
    typeof Mocha !== 'undefined' && !!Mocha
  );
}
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

/**
 * Generated bundle index. Do not edit.
 */


export { Platform, PlatformModule, _getEventTarget, _getFocusedElementPierceShadowDom, _getShadowRoot, _isTestEnvironment, _supportsShadowDom, getRtlScrollAxisType, getSupportedInputTypes, normalizePassiveListenerOptions, supportsPassiveEventListeners, supportsScrollBehavior };ñ   webpack://javascript/esm|./node_modules/@angular-devkit/build-angular/src/babel/webpack-loader.js??ruleSet[1].rules[1].use[0]!./node_modules/source-map-loader/dist/cjs.js??ruleSet[1].rules[2]!./node_modules/@angular/cdk/fesm2020/platform.mjsf  {"version":3,"sources":["webpack://./node_modules/@angular/cdk/fesm2020/platform.mjs"],"names":["i0","PLATFORM_ID","Injectable","Inject","NgModule","isPlatformBrowser","hasV8BreakIterator","Intl","v8BreakIterator","Platform","constructor","_platformId","isBrowser","document","EDGE","test","navigator","userAgent","TRIDENT","BLINK","window","chrome","CSS","WEBKIT","IOS","FIREFOX","ANDROID","SAFARI","Éµfac","Éµprov","type","args","providedIn","Object","decorators","PlatformModule","Éµmod","Éµinj","supportedInputTypes","candidateInputTypes","getSupportedInputTypes","Set","featureTestInput","createElement","filter","value","setAttribute","supportsPassiveEvents","supportsPassiveEventListeners","addEventListener","defineProperty","get","normalizePassiveListenerOptions","options","capture","rtlScrollAxisType","scrollBehaviorSupported","supportsScrollBehavior","Element","documentElement","style","scrollToFunction","prototype","scrollTo","toString","getRtlScrollAxisType","scrollContainer","containerStyle","dir","width","overflow","visibility","pointerEvents","position","content","contentStyle","height","appendChild","body","scrollLeft","remove","shadowDomIsSupported","_supportsShadowDom","head","createShadowRoot","attachShadow","_getShadowRoot","element","rootNode","getRootNode","ShadowRoot","_getFocusedElementPierceShadowDom","activeElement","shadowRoot","newActiveElement","_getEventTarget","event","composedPath","target","_isTestEnvironment","__karma__","jasmine","jest","Mocha"],"mappings":"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","sourcesContent":["import * as i0 from '@angular/core';\nimport { PLATFORM_ID, Injectable, Inject, NgModule } from '@angular/core';\nimport { isPlatformBrowser } from '@angular/common';\n\n/**\n * @license\n * Copyright Google LLC All Rights Reserved.\n *\n * Use of this source code is governed by an MIT-style license that can be\n * found in the LICENSE file at https://angular.io/license\n */\n// Whether the current platform supports the V8 Break Iterator. The V8 check\n// is necessary to detect all Blink based browsers.\nlet hasV8BreakIterator;\n// We need a try/catch around the reference to `Intl`, because accessing it in some cases can\n// cause IE to throw. These cases are tied to particular versions of Windows and can happen if\n// the consumer is providing a polyfilled `Map`. See:\n// https://github.com/Microsoft/ChakraCore/issues/3189\n// https://github.com/angular/components/issues/15687\ntry {\n    hasV8BreakIterator = typeof Intl !== 'undefined' && Intl.v8BreakIterator;\n}\ncatch {\n    hasV8BreakIterator = false;\n}\n/**\n * Service to detect the current platform by comparing the userAgent strings and\n * checking browser-specific global properties.\n */\nclass Platform {\n    constructor(_platformId) {\n        this._platformId = _platformId;\n        // We want to use the Angular platform check because if the Document is shimmed\n        // without the navigator, the following checks will fail. This is preferred because\n        // sometimes the Document may be shimmed without the user's knowledge or intention\n        /** Whether the Angular application is being rendered in the browser. */\n        this.isBrowser = this._platformId\n            ? isPlatformBrowser(this._platformId)\n            : typeof document === 'object' && !!document;\n        /** Whether the current browser is Microsoft Edge. */\n        this.EDGE = this.isBrowser && /(edge)/i.test(navigator.userAgent);\n        /** Whether the current rendering engine is Microsoft Trident. */\n        this.TRIDENT = this.isBrowser && /(msie|trident)/i.test(navigator.userAgent);\n        // EdgeHTML and Trident mock Blink specific things and need to be excluded from this check.\n        /** Whether the current rendering engine is Blink. */\n        this.BLINK = this.isBrowser &&\n            !!(window.chrome || hasV8BreakIterator) &&\n            typeof CSS !== 'undefined' &&\n            !this.EDGE &&\n            !this.TRIDENT;\n        // Webkit is part of the userAgent in EdgeHTML, Blink and Trident. Therefore we need to\n        // ensure that Webkit runs standalone and is not used as another engine's base.\n        /** Whether the current rendering engine is WebKit. */\n        this.WEBKIT = this.isBrowser &&\n            /AppleWebKit/i.test(navigator.userAgent) &&\n            !this.BLINK &&\n            !this.EDGE &&\n            !this.TRIDENT;\n        /** Whether the current platform is Apple iOS. */\n        this.IOS = this.isBrowser && /iPad|iPhone|iPod/.test(navigator.userAgent) && !('MSStream' in window);\n        // It's difficult to detect the plain Gecko engine, because most of the browsers identify\n        // them self as Gecko-like browsers and modify the userAgent's according to that.\n        // Since we only cover one explicit Firefox case, we can simply check for Firefox\n        // instead of having an unstable check for Gecko.\n        /** Whether the current browser is Firefox. */\n        this.FIREFOX = this.isBrowser && /(firefox|minefield)/i.test(navigator.userAgent);\n        /** Whether the current platform is Android. */\n        // Trident on mobile adds the android platform to the userAgent to trick detections.\n        this.ANDROID = this.isBrowser && /android/i.test(navigator.userAgent) && !this.TRIDENT;\n        // Safari browsers will include the Safari keyword in their userAgent. Some browsers may fake\n        // this and just place the Safari keyword in the userAgent. To be more safe about Safari every\n        // Safari browser should also use Webkit as its layout engine.\n        /** Whether the current browser is Safari. */\n        this.SAFARI = this.isBrowser && /safari/i.test(navigator.userAgent) && this.WEBKIT;\n    }\n}\nPlatform.Éµfac = i0.ÉµÉµngDeclareFactory({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: Platform, deps: [{ token: PLATFORM_ID }], target: i0.ÉµÉµFactoryTarget.Injectable });\nPlatform.Éµprov = i0.ÉµÉµngDeclareInjectable({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: Platform, providedIn: 'root' });\ni0.ÉµÉµngDeclareClassMetadata({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: Platform, decorators: [{\n            type: Injectable,\n            args: [{ providedIn: 'root' }]\n        }], ctorParameters: function () { return [{ type: Object, decorators: [{\n                    type: Inject,\n                    args: [PLATFORM_ID]\n                }] }]; } });\n\n/**\n * @license\n * Copyright Google LLC All Rights Reserved.\n *\n * Use of this source code is governed by an MIT-style license that can be\n * found in the LICENSE file at https://angular.io/license\n */\nclass PlatformModule {\n}\nPlatformModule.Éµfac = i0.ÉµÉµngDeclareFactory({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: PlatformModule, deps: [], target: i0.ÉµÉµFactoryTarget.NgModule });\nPlatformModule.Éµmod = i0.ÉµÉµngDeclareNgModule({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: PlatformModule });\nPlatformModule.Éµinj = i0.ÉµÉµngDeclareInjector({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: PlatformModule });\ni0.ÉµÉµngDeclareClassMetadata({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: PlatformModule, decorators: [{\n            type: NgModule,\n            args: [{}]\n        }] });\n\n/**\n * @license\n * Copyright Google LLC All Rights Reserved.\n *\n * Use of this source code is governed by an MIT-style license that can be\n * found in the LICENSE file at https://angular.io/license\n */\n/** Cached result Set of input types support by the current browser. */\nlet supportedInputTypes;\n/** Types of `<input>` that *might* be supported. */\nconst candidateInputTypes = [\n    // `color` must come first. Chrome 56 shows a warning if we change the type to `color` after\n    // first changing it to something else:\n    // The specified value \"\" does not conform to the required format.\n    // The format is \"#rrggbb\" where rr, gg, bb are two-digit hexadecimal numbers.\n    'color',\n    'button',\n    'checkbox',\n    'date',\n    'datetime-local',\n    'email',\n    'file',\n    'hidden',\n    'image',\n    'month',\n    'number',\n    'password',\n    'radio',\n    'range',\n    'reset',\n    'search',\n    'submit',\n    'tel',\n    'text',\n    'time',\n    'url',\n    'week',\n];\n/** @returns The input types supported by this browser. */\nfunction getSupportedInputTypes() {\n    // Result is cached.\n    if (supportedInputTypes) {\n        return supportedInputTypes;\n    }\n    // We can't check if an input type is not supported until we're on the browser, so say that\n    // everything is supported when not on the browser. We don't use `Platform` here since it's\n    // just a helper function and can't inject it.\n    if (typeof document !== 'object' || !document) {\n        supportedInputTypes = new Set(candidateInputTypes);\n        return supportedInputTypes;\n    }\n    let featureTestInput = document.createElement('input');\n    supportedInputTypes = new Set(candidateInputTypes.filter(value => {\n        featureTestInput.setAttribute('type', value);\n        return featureTestInput.type === value;\n    }));\n    return supportedInputTypes;\n}\n\n/**\n * @license\n * Copyright Google LLC All Rights Reserved.\n *\n * Use of this source code is governed by an MIT-style license that can be\n * found in the LICENSE file at https://angular.io/license\n */\n/** Cached result of whether the user's browser supports passive event listeners. */\nlet supportsPassiveEvents;\n/**\n * Checks whether the user's browser supports passive event listeners.\n * See: https://github.com/WICG/EventListenerOptions/blob/gh-pages/explainer.md\n */\nfunction supportsPassiveEventListeners() {\n    if (supportsPassiveEvents == null && typeof window !== 'undefined') {\n        try {\n            window.addEventListener('test', null, Object.defineProperty({}, 'passive', {\n                get: () => (supportsPassiveEvents = true),\n            }));\n        }\n        finally {\n            supportsPassiveEvents = supportsPassiveEvents || false;\n        }\n    }\n    return supportsPassiveEvents;\n}\n/**\n * Normalizes an `AddEventListener` object to something that can be passed\n * to `addEventListener` on any browser, no matter whether it supports the\n * `options` parameter.\n * @param options Object to be normalized.\n */\nfunction normalizePassiveListenerOptions(options) {\n    return supportsPassiveEventListeners() ? options : !!options.capture;\n}\n\n/**\n * @license\n * Copyright Google LLC All Rights Reserved.\n *\n * Use of this source code is governed by an MIT-style license that can be\n * found in the LICENSE file at https://angular.io/license\n */\n/** Cached result of the way the browser handles the horizontal scroll axis in RTL mode. */\nlet rtlScrollAxisType;\n/** Cached result of the check that indicates whether the browser supports scroll behaviors. */\nlet scrollBehaviorSupported;\n/** Check whether the browser supports scroll behaviors. */\nfunction supportsScrollBehavior() {\n    if (scrollBehaviorSupported == null) {\n        // If we're not in the browser, it can't be supported. Also check for `Element`, because\n        // some projects stub out the global `document` during SSR which can throw us off.\n        if (typeof document !== 'object' || !document || typeof Element !== 'function' || !Element) {\n            scrollBehaviorSupported = false;\n            return scrollBehaviorSupported;\n        }\n        // If the element can have a `scrollBehavior` style, we can be sure that it's supported.\n        if ('scrollBehavior' in document.documentElement.style) {\n            scrollBehaviorSupported = true;\n        }\n        else {\n            // At this point we have 3 possibilities: `scrollTo` isn't supported at all, it's\n            // supported but it doesn't handle scroll behavior, or it has been polyfilled.\n            const scrollToFunction = Element.prototype.scrollTo;\n            if (scrollToFunction) {\n                // We can detect if the function has been polyfilled by calling `toString` on it. Native\n                // functions are obfuscated using `[native code]`, whereas if it was overwritten we'd get\n                // the actual function source. Via https://davidwalsh.name/detect-native-function. Consider\n                // polyfilled functions as supporting scroll behavior.\n                scrollBehaviorSupported = !/\\{\\s*\\[native code\\]\\s*\\}/.test(scrollToFunction.toString());\n            }\n            else {\n                scrollBehaviorSupported = false;\n            }\n        }\n    }\n    return scrollBehaviorSupported;\n}\n/**\n * Checks the type of RTL scroll axis used by this browser. As of time of writing, Chrome is NORMAL,\n * Firefox & Safari are NEGATED, and IE & Edge are INVERTED.\n */\nfunction getRtlScrollAxisType() {\n    // We can't check unless we're on the browser. Just assume 'normal' if we're not.\n    if (typeof document !== 'object' || !document) {\n        return 0 /* NORMAL */;\n    }\n    if (rtlScrollAxisType == null) {\n        // Create a 1px wide scrolling container and a 2px wide content element.\n        const scrollContainer = document.createElement('div');\n        const containerStyle = scrollContainer.style;\n        scrollContainer.dir = 'rtl';\n        containerStyle.width = '1px';\n        containerStyle.overflow = 'auto';\n        containerStyle.visibility = 'hidden';\n        containerStyle.pointerEvents = 'none';\n        containerStyle.position = 'absolute';\n        const content = document.createElement('div');\n        const contentStyle = content.style;\n        contentStyle.width = '2px';\n        contentStyle.height = '1px';\n        scrollContainer.appendChild(content);\n        document.body.appendChild(scrollContainer);\n        rtlScrollAxisType = 0 /* NORMAL */;\n        // The viewport starts scrolled all the way to the right in RTL mode. If we are in a NORMAL\n        // browser this would mean that the scrollLeft should be 1. If it's zero instead we know we're\n        // dealing with one of the other two types of browsers.\n        if (scrollContainer.scrollLeft === 0) {\n            // In a NEGATED browser the scrollLeft is always somewhere in [-maxScrollAmount, 0]. For an\n            // INVERTED browser it is always somewhere in [0, maxScrollAmount]. We can determine which by\n            // setting to the scrollLeft to 1. This is past the max for a NEGATED browser, so it will\n            // return 0 when we read it again.\n            scrollContainer.scrollLeft = 1;\n            rtlScrollAxisType =\n                scrollContainer.scrollLeft === 0 ? 1 /* NEGATED */ : 2 /* INVERTED */;\n        }\n        scrollContainer.remove();\n    }\n    return rtlScrollAxisType;\n}\n\n/**\n * @license\n * Copyright Google LLC All Rights Reserved.\n *\n * Use of this source code is governed by an MIT-style license that can be\n * found in the LICENSE file at https://angular.io/license\n */\nlet shadowDomIsSupported;\n/** Checks whether the user's browser support Shadow DOM. */\nfunction _supportsShadowDom() {\n    if (shadowDomIsSupported == null) {\n        const head = typeof document !== 'undefined' ? document.head : null;\n        shadowDomIsSupported = !!(head && (head.createShadowRoot || head.attachShadow));\n    }\n    return shadowDomIsSupported;\n}\n/** Gets the shadow root of an element, if supported and the element is inside the Shadow DOM. */\nfunction _getShadowRoot(element) {\n    if (_supportsShadowDom()) {\n        const rootNode = element.getRootNode ? element.getRootNode() : null;\n        // Note that this should be caught by `_supportsShadowDom`, but some\n        // teams have been able to hit this code path on unsupported browsers.\n        if (typeof ShadowRoot !== 'undefined' && ShadowRoot && rootNode instanceof ShadowRoot) {\n            return rootNode;\n        }\n    }\n    return null;\n}\n/**\n * Gets the currently-focused element on the page while\n * also piercing through Shadow DOM boundaries.\n */\nfunction _getFocusedElementPierceShadowDom() {\n    let activeElement = typeof document !== 'undefined' && document\n        ? document.activeElement\n        : null;\n    while (activeElement && activeElement.shadowRoot) {\n        const newActiveElement = activeElement.shadowRoot.activeElement;\n        if (newActiveElement === activeElement) {\n            break;\n        }\n        else {\n            activeElement = newActiveElement;\n        }\n    }\n    return activeElement;\n}\n/** Gets the target of an event while accounting for Shadow DOM. */\nfunction _getEventTarget(event) {\n    // If an event is bound outside the Shadow DOM, the `event.target` will\n    // point to the shadow root so we have to use `composedPath` instead.\n    return (event.composedPath ? event.composedPath()[0] : event.target);\n}\n\n/**\n * @license\n * Copyright Google LLC All Rights Reserved.\n *\n * Use of this source code is governed by an MIT-style license that can be\n * found in the LICENSE file at https://angular.io/license\n */\n/** Gets whether the code is currently running in a test environment. */\nfunction _isTestEnvironment() {\n    // We can't use `declare const` because it causes conflicts inside Google with the real typings\n    // for these symbols and we can't read them off the global object, because they don't appear to\n    // be attached there for some runners like Jest.\n    // (see: https://github.com/angular/components/issues/23365#issuecomment-938146643)\n    return (\n    // @ts-ignore\n    (typeof __karma__ !== 'undefined' && !!__karma__) ||\n        // @ts-ignore\n        (typeof jasmine !== 'undefined' && !!jasmine) ||\n        // @ts-ignore\n        (typeof jest !== 'undefined' && !!jest) ||\n        // @ts-ignore\n        (typeof Mocha !== 'undefined' && !!Mocha));\n}\n\n/**\n * @license\n * Copyright Google LLC All Rights Reserved.\n *\n * Use of this source code is governed by an MIT-style license that can be\n * found in the LICENSE file at https://angular.io/license\n */\n\n/**\n * @license\n * Copyright Google LLC All Rights Reserved.\n *\n * Use of this source code is governed by an MIT-style license that can be\n * found in the LICENSE file at https://angular.io/license\n */\n\n/**\n * Generated bundle index. Do not edit.\n */\n\nexport { Platform, PlatformModule, _getEventTarget, _getFocusedElementPierceShadowDom, _getShadowRoot, _isTestEnvironment, _supportsShadowDom, getRtlScrollAxisType, getSupportedInputTypes, normalizePassiveListenerOptions, supportsPassiveEventListeners, supportsScrollBehavior };\n"],"file":"x"}`°øÿÿ±øÿÿ²øÿÿ@³øÿÿµøÿÿ¶øÿÿşÆøÿÿ	ÇøÿÿÈøÿÿÉøÿÿÊøÿÿe729376d7d226109ËøÿÿÌøÿÿ`–getSupportedInputTypessupportsPassiveEventListeners^úÿÿ–supportsScrollBehavior”getRtlScrollAxisType’_supportsShadowDomûÿÿàùÿÿcúÿÿ’_isTestEnvironment’hasV8BreakIterator¥ùÿÿˆûÿÿ“supportedInputTypes“candidateInputTypes•supportsPassiveEvents‘rtlScrollAxisType—scrollBehaviorSupported”shadowDomIsSupported@    ğÆÚÒwBûøÿÿüøÿÿÕşÿÿdÿ ÿ ı€ `$ `$€a%o `J€`p@¤    `4aA©;  ¿<  @¨   A¨    `ùÿÿùÿÿ `$ùÿÿùÿÿ `Jùÿÿùÿÿ `4‘isPlatformBrowserşA9  J  ùÿÿùÿÿÿc'('9ùÿÿùÿÿAc  n  ùÿÿùÿÿÿcPP(‹PLATFORM_IDşAo  z  ùÿÿùÿÿÿcP)P4ùÿÿùÿÿA¢  ·   ùÿÿ ùÿÿÿcS S5ùÿÿùÿÿAE  Y  ıøÿÿıøÿÿÿcZ5ZIùÿÿùÿÿAq  {  úøÿÿúøÿÿÿc[
[ùÿÿùÿÿA  	  ÷øÿÿ÷øÿÿÿcccñğA  %  õøÿÿõøÿÿÿcddOûÿÿùÿÿA¹  Ì  òøÿÿòøÿÿÿcx%x8PûÿÿùÿÿA  "  ïøÿÿïøÿÿÿc{%{8ùÿÿ ùÿÿAm    ìøÿÿìøÿÿÿc~5~IYûÿÿXûÿÿAŸ  §  éøÿÿéøÿÿÿc
hùÿÿhùÿÿ@¨   A¨    JûÿÿJûÿÿ@¨   A¨    "úÿÿ"úÿÿ@¨   A¨    ùÿÿùÿÿ@¨   A¨    ÄúÿÿÄúÿÿ@¨   A¨    ¼¼@¨   A¨    ºº@¨   A¨    ¸¸@¨   A¨    ´´@¨   A¨    úÿÿúÿÿ@¨   A¨    ³³@¨   A¨    ³³@¨   A¨     
Ú   import { coerceElement, coerceBooleanProperty, coerceNumberProperty } from '@angular/cdk/coercion';
import * as i0 from '@angular/core';
import { Injectable, EventEmitter, Directive, Output, Input, NgModule } from '@angular/core';
import { Observable, Subject } from 'rxjs';
import { debounceTime } from 'rxjs/operators';
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

/**
 * Factory that creates a new MutationObserver and allows us to stub it out in unit tests.
 * @docs-private
 */

class MutationObserverFactory {
  create(callback) {
    return typeof MutationObserver === 'undefined' ? null : new MutationObserver(callback);
  }

}

MutationObserverFactory.Éµfac = function MutationObserverFactory_Factory(t) {
  return new (t || MutationObserverFactory)();
};

MutationObserverFactory.Éµprov = /* @__PURE__ */i0.ÉµÉµdefineInjectable({
  token: MutationObserverFactory,
  factory: MutationObserverFactory.Éµfac,
  providedIn: 'root'
});

(function () {
  (typeof ngDevMode === "undefined" || ngDevMode) && i0.ÉµsetClassMetadata(MutationObserverFactory, [{
    type: Injectable,
    args: [{
      providedIn: 'root'
    }]
  }], null, null);
})();
/** An injectable service that allows watching elements for changes to their content. */


class ContentObserver {
  constructor(_mutationObserverFactory) {
    this._mutationObserverFactory = _mutationObserverFactory;
    /** Keeps track of the existing MutationObservers so they can be reused. */

    this._observedElements = new Map();
  }

  ngOnDestroy() {
    this._observedElements.forEach((_, element) => this._cleanupObserver(element));
  }

  observe(elementOrRef) {
    const element = coerceElement(elementOrRef);
    return new Observable(observer => {
      const stream = this._observeElement(element);

      const subscription = stream.subscribe(observer);
      return () => {
        subscription.unsubscribe();

        this._unobserveElement(element);
      };
    });
  }
  /**
   * Observes the given element by using the existing MutationObserver if available, or creating a
   * new one if not.
   */


  _observeElement(element) {
    if (!this._observedElements.has(element)) {
      const stream = new Subject();

      const observer = this._mutationObserverFactory.create(mutations => stream.next(mutations));

      if (observer) {
        observer.observe(element, {
          characterData: true,
          childList: true,
          subtree: true
        });
      }

      this._observedElements.set(element, {
        observer,
        stream,
        count: 1
      });
    } else {
      this._observedElements.get(element).count++;
    }

    return this._observedElements.get(element).stream;
  }
  /**
   * Un-observes the given element and cleans up the underlying MutationObserver if nobody else is
   * observing this element.
   */


  _unobserveElement(element) {
    if (this._observedElements.has(element)) {
      this._observedElements.get(element).count--;

      if (!this._observedElements.get(element).count) {
        this._cleanupObserver(element);
      }
    }
  }
  /** Clean up the underlying MutationObserver for the specified element. */


  _cleanupObserver(element) {
    if (this._observedElements.has(element)) {
      const {
        observer,
        stream
      } = this._observedElements.get(element);

      if (observer) {
        observer.disconnect();
      }

      stream.complete();

      this._observedElements.delete(element);
    }
  }

}

ContentObserver.Éµfac = function ContentObserver_Factory(t) {
  return new (t || ContentObserver)(i0.ÉµÉµinject(MutationObserverFactory));
};

ContentObserver.Éµprov = /* @__PURE__ */i0.ÉµÉµdefineInjectable({
  token: ContentObserver,
  factory: ContentObserver.Éµfac,
  providedIn: 'root'
});

(function () {
  (typeof ngDevMode === "undefined" || ngDevMode) && i0.ÉµsetClassMetadata(ContentObserver, [{
    type: Injectable,
    args: [{
      providedIn: 'root'
    }]
  }], function () {
    return [{
      type: MutationObserverFactory
    }];
  }, null);
})();
/**
 * Directive that triggers a callback whenever the content of
 * its associated element has changed.
 */


class CdkObserveContent {
  constructor(_contentObserver, _elementRef, _ngZone) {
    this._contentObserver = _contentObserver;
    this._elementRef = _elementRef;
    this._ngZone = _ngZone;
    /** Event emitted for each change in the element's content. */

    this.event = new EventEmitter();
    this._disabled = false;
    this._currentSubscription = null;
  }
  /**
   * Whether observing content is disabled. This option can be used
   * to disconnect the underlying MutationObserver until it is needed.
   */


  get disabled() {
    return this._disabled;
  }

  set disabled(value) {
    this._disabled = coerceBooleanProperty(value);
    this._disabled ? this._unsubscribe() : this._subscribe();
  }
  /** Debounce interval for emitting the changes. */


  get debounce() {
    return this._debounce;
  }

  set debounce(value) {
    this._debounce = coerceNumberProperty(value);

    this._subscribe();
  }

  ngAfterContentInit() {
    if (!this._currentSubscription && !this.disabled) {
      this._subscribe();
    }
  }

  ngOnDestroy() {
    this._unsubscribe();
  }

  _subscribe() {
    this._unsubscribe();

    const stream = this._contentObserver.observe(this._elementRef); // TODO(mmalerba): We shouldn't be emitting on this @Output() outside the zone.
    // Consider brining it back inside the zone next time we're making breaking changes.
    // Bringing it back inside can cause things like infinite change detection loops and changed
    // after checked errors if people's code isn't handling it properly.


    this._ngZone.runOutsideAngular(() => {
      this._currentSubscription = (this.debounce ? stream.pipe(debounceTime(this.debounce)) : stream).subscribe(this.event);
    });
  }

  _unsubscribe() {
    this._currentSubscription?.unsubscribe();
  }

}

CdkObserveContent.Éµfac = function CdkObserveContent_Factory(t) {
  return new (t || CdkObserveContent)(i0.ÉµÉµdirectiveInject(ContentObserver), i0.ÉµÉµdirectiveInject(i0.ElementRef), i0.ÉµÉµdirectiveInject(i0.NgZone));
};

CdkObserveContent.Éµdir = /* @__PURE__ */i0.ÉµÉµdefineDirective({
  type: CdkObserveContent,
  selectors: [["", "cdkObserveContent", ""]],
  inputs: {
    disabled: ["cdkObserveContentDisabled", "disabled"],
    debounce: "debounce"
  },
  outputs: {
    event: "cdkObserveContent"
  },
  exportAs: ["cdkObserveContent"]
});

(function () {
  (typeof ngDevMode === "undefined" || ngDevMode) && i0.ÉµsetClassMetadata(CdkObserveContent, [{
    type: Directive,
    args: [{
      selector: '[cdkObserveContent]',
      exportAs: 'cdkObserveContent'
    }]
  }], function () {
    return [{
      type: ContentObserver
    }, {
      type: i0.ElementRef
    }, {
      type: i0.NgZone
    }];
  }, {
    event: [{
      type: Output,
      args: ['cdkObserveContent']
    }],
    disabled: [{
      type: Input,
      args: ['cdkObserveContentDisabled']
    }],
    debounce: [{
      type: Input
    }]
  });
})();

class ObserversModule {}

ObserversModule.Éµfac = function ObserversModule_Factory(t) {
  return new (t || ObserversModule)();
};

ObserversModule.Éµmod = /* @__PURE__ */i0.ÉµÉµdefineNgModule({
  type: ObserversModule
});
ObserversModule.Éµinj = /* @__PURE__ */i0.ÉµÉµdefineInjector({
  providers: [MutationObserverFactory]
});

(function () {
  (typeof ngDevMode === "undefined" || ngDevMode) && i0.ÉµsetClassMetadata(ObserversModule, [{
    type: NgModule,
    args: [{
      exports: [CdkObserveContent],
      declarations: [CdkObserveContent],
      providers: [MutationObserverFactory]
    }]
  }], null, null);
})();
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

/**
 * Generated bundle index. Do not edit.
 */


export { CdkObserveContent, ContentObserver, MutationObserverFactory, ObserversModule };ò   webpack://javascript/esm|./node_modules/@angular-devkit/build-angular/src/babel/webpack-loader.js??ruleSet[1].rules[1].use[0]!./node_modules/source-map-loader/dist/cjs.js??ruleSet[1].rules[2]!./node_modules/@angular/cdk/fesm2020/observers.mjsÖA  {"version":3,"sources":["webpack://./node_modules/@angular/cdk/fesm2020/observers.mjs"],"names":["coerceElement","coerceBooleanProperty","coerceNumberProperty","i0","Injectable","EventEmitter","Directive","Output","Input","NgModule","Observable","Subject","debounceTime","MutationObserverFactory","create","callback","MutationObserver","Éµfac","Éµprov","type","args","providedIn","ContentObserver","constructor","_mutationObserverFactory","_observedElements","Map","ngOnDestroy","forEach","_","element","_cleanupObserver","observe","elementOrRef","observer","stream","_observeElement","subscription","subscribe","unsubscribe","_unobserveElement","has","mutations","next","characterData","childList","subtree","set","count","get","disconnect","complete","delete","CdkObserveContent","_contentObserver","_elementRef","_ngZone","event","_disabled","_currentSubscription","disabled","value","_unsubscribe","_subscribe","debounce","_debounce","ngAfterContentInit","runOutsideAngular","pipe","ElementRef","NgZone","Éµdir","selector","exportAs","ObserversModule","Éµmod","Éµinj","exports","declarations","providers"],"mappings":"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","sourcesContent":["import { coerceElement, coerceBooleanProperty, coerceNumberProperty } from '@angular/cdk/coercion';\nimport * as i0 from '@angular/core';\nimport { Injectable, EventEmitter, Directive, Output, Input, NgModule } from '@angular/core';\nimport { Observable, Subject } from 'rxjs';\nimport { debounceTime } from 'rxjs/operators';\n\n/**\n * @license\n * Copyright Google LLC All Rights Reserved.\n *\n * Use of this source code is governed by an MIT-style license that can be\n * found in the LICENSE file at https://angular.io/license\n */\n/**\n * Factory that creates a new MutationObserver and allows us to stub it out in unit tests.\n * @docs-private\n */\nclass MutationObserverFactory {\n    create(callback) {\n        return typeof MutationObserver === 'undefined' ? null : new MutationObserver(callback);\n    }\n}\nMutationObserverFactory.Éµfac = i0.ÉµÉµngDeclareFactory({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: MutationObserverFactory, deps: [], target: i0.ÉµÉµFactoryTarget.Injectable });\nMutationObserverFactory.Éµprov = i0.ÉµÉµngDeclareInjectable({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: MutationObserverFactory, providedIn: 'root' });\ni0.ÉµÉµngDeclareClassMetadata({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: MutationObserverFactory, decorators: [{\n            type: Injectable,\n            args: [{ providedIn: 'root' }]\n        }] });\n/** An injectable service that allows watching elements for changes to their content. */\nclass ContentObserver {\n    constructor(_mutationObserverFactory) {\n        this._mutationObserverFactory = _mutationObserverFactory;\n        /** Keeps track of the existing MutationObservers so they can be reused. */\n        this._observedElements = new Map();\n    }\n    ngOnDestroy() {\n        this._observedElements.forEach((_, element) => this._cleanupObserver(element));\n    }\n    observe(elementOrRef) {\n        const element = coerceElement(elementOrRef);\n        return new Observable((observer) => {\n            const stream = this._observeElement(element);\n            const subscription = stream.subscribe(observer);\n            return () => {\n                subscription.unsubscribe();\n                this._unobserveElement(element);\n            };\n        });\n    }\n    /**\n     * Observes the given element by using the existing MutationObserver if available, or creating a\n     * new one if not.\n     */\n    _observeElement(element) {\n        if (!this._observedElements.has(element)) {\n            const stream = new Subject();\n            const observer = this._mutationObserverFactory.create(mutations => stream.next(mutations));\n            if (observer) {\n                observer.observe(element, {\n                    characterData: true,\n                    childList: true,\n                    subtree: true,\n                });\n            }\n            this._observedElements.set(element, { observer, stream, count: 1 });\n        }\n        else {\n            this._observedElements.get(element).count++;\n        }\n        return this._observedElements.get(element).stream;\n    }\n    /**\n     * Un-observes the given element and cleans up the underlying MutationObserver if nobody else is\n     * observing this element.\n     */\n    _unobserveElement(element) {\n        if (this._observedElements.has(element)) {\n            this._observedElements.get(element).count--;\n            if (!this._observedElements.get(element).count) {\n                this._cleanupObserver(element);\n            }\n        }\n    }\n    /** Clean up the underlying MutationObserver for the specified element. */\n    _cleanupObserver(element) {\n        if (this._observedElements.has(element)) {\n            const { observer, stream } = this._observedElements.get(element);\n            if (observer) {\n                observer.disconnect();\n            }\n            stream.complete();\n            this._observedElements.delete(element);\n        }\n    }\n}\nContentObserver.Éµfac = i0.ÉµÉµngDeclareFactory({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: ContentObserver, deps: [{ token: MutationObserverFactory }], target: i0.ÉµÉµFactoryTarget.Injectable });\nContentObserver.Éµprov = i0.ÉµÉµngDeclareInjectable({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: ContentObserver, providedIn: 'root' });\ni0.ÉµÉµngDeclareClassMetadata({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: ContentObserver, decorators: [{\n            type: Injectable,\n            args: [{ providedIn: 'root' }]\n        }], ctorParameters: function () { return [{ type: MutationObserverFactory }]; } });\n/**\n * Directive that triggers a callback whenever the content of\n * its associated element has changed.\n */\nclass CdkObserveContent {\n    constructor(_contentObserver, _elementRef, _ngZone) {\n        this._contentObserver = _contentObserver;\n        this._elementRef = _elementRef;\n        this._ngZone = _ngZone;\n        /** Event emitted for each change in the element's content. */\n        this.event = new EventEmitter();\n        this._disabled = false;\n        this._currentSubscription = null;\n    }\n    /**\n     * Whether observing content is disabled. This option can be used\n     * to disconnect the underlying MutationObserver until it is needed.\n     */\n    get disabled() {\n        return this._disabled;\n    }\n    set disabled(value) {\n        this._disabled = coerceBooleanProperty(value);\n        this._disabled ? this._unsubscribe() : this._subscribe();\n    }\n    /** Debounce interval for emitting the changes. */\n    get debounce() {\n        return this._debounce;\n    }\n    set debounce(value) {\n        this._debounce = coerceNumberProperty(value);\n        this._subscribe();\n    }\n    ngAfterContentInit() {\n        if (!this._currentSubscription && !this.disabled) {\n            this._subscribe();\n        }\n    }\n    ngOnDestroy() {\n        this._unsubscribe();\n    }\n    _subscribe() {\n        this._unsubscribe();\n        const stream = this._contentObserver.observe(this._elementRef);\n        // TODO(mmalerba): We shouldn't be emitting on this @Output() outside the zone.\n        // Consider brining it back inside the zone next time we're making breaking changes.\n        // Bringing it back inside can cause things like infinite change detection loops and changed\n        // after checked errors if people's code isn't handling it properly.\n        this._ngZone.runOutsideAngular(() => {\n            this._currentSubscription = (this.debounce ? stream.pipe(debounceTime(this.debounce)) : stream).subscribe(this.event);\n        });\n    }\n    _unsubscribe() {\n        this._currentSubscription?.unsubscribe();\n    }\n}\nCdkObserveContent.Éµfac = i0.ÉµÉµngDeclareFactory({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: CdkObserveContent, deps: [{ token: ContentObserver }, { token: i0.ElementRef }, { token: i0.NgZone }], target: i0.ÉµÉµFactoryTarget.Directive });\nCdkObserveContent.Éµdir = i0.ÉµÉµngDeclareDirective({ minVersion: \"12.0.0\", version: \"13.0.1\", type: CdkObserveContent, selector: \"[cdkObserveContent]\", inputs: { disabled: [\"cdkObserveContentDisabled\", \"disabled\"], debounce: \"debounce\" }, outputs: { event: \"cdkObserveContent\" }, exportAs: [\"cdkObserveContent\"], ngImport: i0 });\ni0.ÉµÉµngDeclareClassMetadata({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: CdkObserveContent, decorators: [{\n            type: Directive,\n            args: [{\n                    selector: '[cdkObserveContent]',\n                    exportAs: 'cdkObserveContent',\n                }]\n        }], ctorParameters: function () { return [{ type: ContentObserver }, { type: i0.ElementRef }, { type: i0.NgZone }]; }, propDecorators: { event: [{\n                type: Output,\n                args: ['cdkObserveContent']\n            }], disabled: [{\n                type: Input,\n                args: ['cdkObserveContentDisabled']\n            }], debounce: [{\n                type: Input\n            }] } });\nclass ObserversModule {\n}\nObserversModule.Éµfac = i0.ÉµÉµngDeclareFactory({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: ObserversModule, deps: [], target: i0.ÉµÉµFactoryTarget.NgModule });\nObserversModule.Éµmod = i0.ÉµÉµngDeclareNgModule({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: ObserversModule, declarations: [CdkObserveContent], exports: [CdkObserveContent] });\nObserversModule.Éµinj = i0.ÉµÉµngDeclareInjector({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: ObserversModule, providers: [MutationObserverFactory] });\ni0.ÉµÉµngDeclareClassMetadata({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: ObserversModule, decorators: [{\n            type: NgModule,\n            args: [{\n                    exports: [CdkObserveContent],\n                    declarations: [CdkObserveContent],\n                    providers: [MutationObserverFactory],\n                }]\n        }] });\n\n/**\n * @license\n * Copyright Google LLC All Rights Reserved.\n *\n * Use of this source code is governed by an MIT-style license that can be\n * found in the LICENSE file at https://angular.io/license\n */\n\n/**\n * @license\n * Copyright Google LLC All Rights Reserved.\n *\n * Use of this source code is governed by an MIT-style license that can be\n * found in the LICENSE file at https://angular.io/license\n */\n\n/**\n * Generated bundle index. Do not edit.\n */\n\nexport { CdkObserveContent, ContentObserver, MutationObserverFactory, ObserversModule };\n"],"file":"x"}`SøÿÿTøÿÿUøÿÿ@VøÿÿXøÿÿYøÿÿşiøÿÿ	jøÿÿkøÿÿløÿÿmøÿÿd68462e185c0da14nøÿÿoøÿÿ—MutationObserverFactory~úÿÿ‘CdkObserveContent4ûÿÿ@    ğÆÚÒwB©øÿÿªøÿÿŒşÿÿdÿ ÿ ı€ `c `c€`d@ˆ    `$€A‰   æ    `]€Aç      `+€A  A   `.aAa   ¹   @G   @G  `X`(ÃøÿÿÃøÿÿ `c¹øÿÿ¹øÿÿ `$¸øÿÿ¸øÿÿ `]ºøÿÿºøÿÿ `+½øÿÿ½øÿÿ `.ÏøÿÿÇøÿÿAÊ  ß  ³øÿÿ³øÿÿÿc/DĞøÿÿÄøÿÿA‹  Ÿ  °øÿÿ°øÿÿÿc%5%IÑøÿÿĞøÿÿAÆ  Ğ  ­øÿÿ­øÿÿÿc&
&„úÿÿƒúÿÿA
    ³øÿÿ³øÿÿÿc<<!¶üÿÿµüÿÿA6  @  ªøÿÿªøÿÿÿc==ÒøÿÿÑøÿÿA	  &	  §øÿÿ§øÿÿÿcPP ´øÿÿµøÿÿAŒ  —  ¡øÿÿ¡øÿÿÿ@   `$@   `/ºøÿÿ²øÿÿAŞ  ó  øÿÿøÿÿÿ@   `'@   `<»øÿÿ¯øÿÿA  £  ›øÿÿ›øÿÿÿ@—   `5@—   `Ië¼øÿÿAÂ  Ì  ™øÿÿ™øÿÿÿ@˜   
@˜   `ºúÿÿ¹úÿÿAã  ï  –øÿÿ–øÿÿÿ@¯   `@¯   `!GùÿÿFùÿÿA2  G  œøÿÿœøÿÿÿ@¾   `@¾   `*>ÿÿÿ=ÿÿÿA)  =  ™øÿÿ™øÿÿÿ@É   `@É   `)ĞøÿÿÏøÿÿA6  B  ”øÿÿ”øÿÿÿ@â   `?@â   `KIùÿÿøÿÿA1  E  ŠøÿÿŠøÿÿÿ@í   `&@í   `:Fùÿÿ›øÿÿAX  l  ‡øÿÿ‡øÿÿÿ@í   `M@í   `aGùÿÿ˜øÿÿAm  z  „øÿÿ„øÿÿÿ@í   `b@í   `o@ùÿÿ•øÿÿA}  ‘  øÿÿøÿÿÿ@í   `rAí   †   ùÿÿ’øÿÿA’  ›  ~øÿÿ~øÿÿÿCí   ‡   í      JùÿÿøÿÿAË  ß  {øÿÿ{øÿÿÿ@ğ   `(@ğ   `<˜øÿÿŒøÿÿA*  >  xøÿÿxøÿÿÿ@ş   `5@ş   `IOùÿÿNùÿÿA_  h  uøÿÿuøÿÿÿ@ÿ   
@ÿ   `5ùÿÿ†øÿÿA  )  røÿÿrøÿÿÿ@  `@  `ùÿÿƒøÿÿA?  H  oøÿÿoøÿÿÿ@
  `@
  `¨úÿÿ§úÿÿAr  x  løÿÿløÿÿÿ@  `@  `NùÿÿMùÿÿAÁ  Æ  iøÿÿiøÿÿÿ@  `@  `ıKùÿÿA    gøÿÿgøÿÿÿ@  `@  `ÁúÿÿxøÿÿAÙ  ì  døÿÿdøÿÿÿ@!  `&@!  `9ÂúÿÿuøÿÿA1  D  aøÿÿaøÿÿÿ@$  `&@$  `9~øÿÿrøÿÿA·  Ë  ^øÿÿ^øÿÿÿ@)  `5@)  `IËúÿÿÊúÿÿAê  ò  [øÿÿ[øÿÿÿ@*  
@*  `ŒŒ@G   @G  `X	úÿÿ	úÿÿ@G   @G  `X‰‰@G   @G  `X¾úÿÿ¾úÿÿ@G   @G  `X —webpack/lib/ModuleGraph“RestoreProvidedData`ûÿÿˆprovidedcanMangleProvideterminalBinding‹exportsInfo)øÿÿşøÿÿıøÿÿüøÿÿûøÿÿúøÿÿùøÿÿøøÿÿ÷øÿÿöøÿÿõøÿÿôøÿÿóøÿÿò øÿÿñøÿÿğøÿÿïøÿÿîøÿÿíøÿÿìøÿÿëøÿÿêú÷ÿÿéø÷ÿÿèøÿÿçøÿÿæé÷ÿÿåñ÷ÿÿäøÿÿãè÷ÿÿâã÷ÿÿáã÷ÿÿ
`xŞAİLùÿÿÜEşÿÿÛşÿÿÚBÙEşÿÿØùıÿÿ×CÖûıÿÿÕBşÿÿÔ9şÿÿÓşÿÿÒEùÿÿÑDĞ6şÿÿÏüıÿÿÎnøÿÿÍEÌşÿÿËøÿÿÊíıÿÿÉ-şÿÿÈîıÿÿÇFÆşÿÿÅşÿÿÄşÿÿÃşÿÿÂşÿÿÁşÿÿÀşÿÿ¿şÿÿ¾şÿÿ½şÿÿ¼şÿÿ»şÿÿºñıÿÿ¹şÿÿ¸şÿÿ·íıÿÿ¶şÿÿµşÿÿ´şÿÿ³åıÿÿ²ãıÿÿ±G°H¯_øÿÿ®I­Ùıÿÿ¬J«KªL©
şÿÿ¨Tøÿÿ§M¦Æıÿÿ¥ùÿÿ¤Şıÿÿ£Şıÿÿ¢ùÿÿ¡ııÿÿ NŸeøÿÿéıÿÿâıÿÿœŞıÿÿ›Üıÿÿšãıÿÿ™àıÿÿ˜Şıÿÿ—Õıÿÿ–àıÿÿ•İıÿÿ”Øıÿÿ“Öıÿÿ’Òıÿÿ‘ĞıÿÿÍıÿÿ±ıÿÿæıÿÿOŒºıÿÿ‹öıÿÿŠP‰²ıÿÿˆ°ıÿÿ‡«ıÿÿ†íıÿÿ…¯ıÿÿ„¯ıÿÿƒQ‚ºıÿÿR€(øÿÿÿÿÿS~ÿÿÿ×ıÿÿ}ÿÿÿàıÿÿ|ÿÿÿ°ıÿÿ{ÿÿÿúøÿÿzÿÿÿèıÿÿyÿÿÿ¬ıÿÿxÿÿÿàıÿÿwÿÿÿıÿÿvÿÿÿTuÿÿÿøÿÿtÿÿÿ¤ıÿÿsÿÿÿİıÿÿrÿÿÿ¡ıÿÿqÿÿÿUpÿÿÿøÿÿoÿÿÿVnÿÿÿËıÿÿmÿÿÿËıÿÿlÿÿÿWkÿÿÿXjÿÿÿYiÿÿÿZhÿÿÿ*øÿÿgÿÿÿøÿÿ
dÿÿÿ`şÿÿcÿÿÿ`şÿÿbÿÿÿcøÿÿaÿÿÿ_şÿÿ`ÿÿÿ‡ùÿÿ_ÿÿÿZşÿÿ^ÿÿÿ]şÿÿ
`[ÿÿÿ*øÿÿZÿÿÿúÿÿYÿÿÿäøÿÿXÿÿÿ`øÿÿWÿÿÿ†ùÿÿVÿÿÿ~şÿÿUÿÿÿ|şÿÿTÿÿÿzşÿÿSÿÿÿvşÿÿRÿÿÿÕøÿÿQÿÿÿuşÿÿPÿÿÿuşÿÿ
MÿÿÿÎşÿÿLÿÿÿKùÿÿKÿÿÿËşÿÿJÿÿÿ úÿÿ
‡sources“runtimeRequirements„dataŠjavascript«webpack/lib/util/registerExternalSerializerœwebpack-sources/CachedSource   ò  «webpack/lib/util/registerExternalSerializerœwebpack-sources/ConcatSource€«webpack/lib/util/registerExternalSerializer™webpack-sources/RawSource  __webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "asyncScheduler": () => (/* binding */ asyncScheduler),
/* harmony export */   "async": () => (/* binding */ async)
/* harmony export */ });
/* harmony import */ var _AsyncAction__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ./AsyncAction */ 897);
/* harmony import */ var _AsyncScheduler__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./AsyncScheduler */ 2775);
«webpack/lib/util/registerExternalSerializerwebpack-sources/ReplaceSource«webpack/lib/util/registerExternalSerializerŸwebpack-sources/SourceMapSourceÃ   import { AsyncAction } from './AsyncAction';
import { AsyncScheduler } from './AsyncScheduler';
export const asyncScheduler = new AsyncScheduler(AsyncAction);
export const async = asyncScheduler;  webpack://./node_modules/@angular-devkit/build-angular/src/babel/webpack-loader.js??ruleSet[1].rules[1].use[0]!./node_modules/@ngtools/webpack/src/ivy/index.js!./node_modules/source-map-loader/dist/cjs.js??ruleSet[1].rules[2]!./node_modules/rxjs/dist/esm/internal/scheduler/async.js'  {"version":3,"sources":["webpack://./node_modules/rxjs/dist/esm/internal/scheduler/async.js"],"names":["AsyncAction","AsyncScheduler","asyncScheduler","async"],"mappings":"AAAA,SAASA,WAAT,QAA4B,eAA5B;AACA,SAASC,cAAT,QAA+B,kBAA/B;AACA,OAAO,MAAMC,cAAc,GAAG,IAAID,cAAJ,CAAmBD,WAAnB,CAAvB;AACP,OAAO,MAAMG,KAAK,GAAGD,cAAd","sourcesContent":["import { AsyncAction } from './AsyncAction';\nimport { AsyncScheduler } from './AsyncScheduler';\nexport const asyncScheduler = new AsyncScheduler(AsyncAction);\nexport const async = asyncScheduler;\n"],"file":"x"} d+-^`fE‚      ‘   ›   Ÿ   ¥   €€€»_AsyncScheduler__WEBPACK_IMPORTED_MODULE_0__.AsyncSchedulerµ_AsyncAction__WEBPACK_IMPORTED_MODULE_1__.AsyncAction€†buffer†source„size„maps÷ÿÿ¯  __webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "asyncScheduler": () => (/* binding */ asyncScheduler),
/* harmony export */   "async": () => (/* binding */ async)
/* harmony export */ });
/* harmony import */ var _AsyncAction__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ./AsyncAction */ 897);
/* harmony import */ var _AsyncScheduler__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./AsyncScheduler */ 2775);


const asyncScheduler = new _AsyncScheduler__WEBPACK_IMPORTED_MODULE_0__.AsyncScheduler(_AsyncAction__WEBPACK_IMPORTED_MODULE_1__.AsyncAction);
const async = asyncScheduler;”{"finalSource":true}Ó÷ÿÿ‹bufferedMap:úÿÿ(úÿÿˆmappingsñsourcesContent…namesx`   ;;;;;;;AAAA;AACA;AACO,MAAME,cAAc,GAAG,IAAID,2DAAJ,CAAmBD,qDAAnB,CAAvB;AACA,MAAMG,KAAK,GAAGD,cAAdÂwebpack://./node_modules/rxjs/dist/esm/internal/scheduler/async.jsÄ   import { AsyncAction } from './AsyncAction';
import { AsyncScheduler } from './AsyncScheduler';
export const asyncScheduler = new AsyncScheduler(AsyncAction);
export const async = asyncScheduler;
‹AsyncActionAsyncSchedulerasyncScheduler…async   ConcatSourceRawSource  __webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "asyncScheduler": () => (/* binding */ asyncScheduler),
/* harmony export */   "async": () => (/* binding */ async)
/* harmony export */ });
/* harmony import */ var _AsyncAction__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ./AsyncAction */ 897);
/* harmony import */ var _AsyncScheduler__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./AsyncScheduler */ 2775);
   ReplaceSourceSourceMapSourceÃ   import { AsyncAction } from './AsyncAction';
import { AsyncScheduler } from './AsyncScheduler';
export const asyncScheduler = new AsyncScheduler(AsyncAction);
export const async = asyncScheduler;'  {"version":3,"sources":["webpack://./node_modules/rxjs/dist/esm/internal/scheduler/async.js"],"names":["AsyncAction","AsyncScheduler","asyncScheduler","async"],"mappings":"AAAA,SAASA,WAAT,QAA4B,eAA5B;AACA,SAASC,cAAT,QAA+B,kBAA/B;AACA,OAAO,MAAMC,cAAc,GAAG,IAAID,cAAJ,CAAmBD,WAAnB,CAAvB;AACP,OAAO,MAAMG,KAAK,GAAGD,cAAd","sourcesContent":["import { AsyncAction } from './AsyncAction';\nimport { AsyncScheduler } from './AsyncScheduler';\nexport const asyncScheduler = new AsyncScheduler(AsyncAction);\nexport const async = asyncScheduler;\n"],"file":"x"}É   false043undefined4594undefined96102undefined130143_AsyncScheduler__WEBPACK_IMPORTED_MODULE_0__.AsyncSchedulerundefined145155_AsyncAction__WEBPACK_IMPORTED_MODULE_1__.AsyncActionundefined159165undefined
“__webpack_require__•__webpack_require__.r
÷ÿÿ•__webpack_require__.dÕÖ   Ë  «webpack/lib/util/registerExternalSerializerœwebpack-sources/ConcatSource€«webpack/lib/util/registerExternalSerializer™webpack-sources/RawSourceh  __webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "Scheduler": () => (/* binding */ Scheduler)
/* harmony export */ });
/* harmony import */ var _scheduler_dateTimestampProvider__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./scheduler/dateTimestampProvider */ 8205);
«webpack/lib/util/registerExternalSerializerwebpack-sources/ReplaceSource«webpack/lib/util/registerExternalSerializerwebpack-sources/OriginalSource   import { dateTimestampProvider } from './scheduler/dateTimestampProvider';
export class Scheduler {
    constructor(schedulerActionCtor, now = Scheduler.now) {
        this.schedulerActionCtor = schedulerActionCtor;
        this.now = now;
    }
    schedule(work, delay = 0, state) {
        return new this.schedulerActionCtor(this, work).schedule(state, delay);
    }
}
Scheduler.now = dateTimestampProvider.now;
  webpack://./node_modules/@angular-devkit/build-angular/src/babel/webpack-loader.js??ruleSet[1].rules[1].use[0]!./node_modules/@ngtools/webpack/src/ivy/index.js!./node_modules/source-map-loader/dist/cjs.js??ruleSet[1].rules[2]!./node_modules/rxjs/dist/esm/internal/Scheduler.js bIKQA…    €€×_scheduler_dateTimestampProvider__WEBPACK_IMPORTED_MODULE_0__.dateTimestampProvider.nowÛõ  __webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "Scheduler": () => (/* binding */ Scheduler)
/* harmony export */ });
/* harmony import */ var _scheduler_dateTimestampProvider__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./scheduler/dateTimestampProvider */ 8205);

class Scheduler {
    constructor(schedulerActionCtor, now = Scheduler.now) {
        this.schedulerActionCtor = schedulerActionCtor;
        this.now = now;
    }
    schedule(work, delay = 0, state) {
        return new this.schedulerActionCtor(this, work).schedule(state, delay);
    }
}
Scheduler.now = _scheduler_dateTimestampProvider__WEBPACK_IMPORTED_MODULE_0__.dateTimestampProvider.now;
ÜŞâxK   ;;;;;AAA0E;AACnE;AACP;AACA;AACA;AACA;AACA;AACA;AACA;AACA;AACA,gBAAgB,uFAAyB  webpack://./node_modules/@angular-devkit/build-angular/src/babel/webpack-loader.js??ruleSet[1].rules[1].use[0]!./node_modules/@ngtools/webpack/src/ivy/index.js!./node_modules/source-map-loader/dist/cjs.js??ruleSet[1].rules[2]!./node_modules/rxjs/dist/esm/internal/Scheduler.js   import { dateTimestampProvider } from './scheduler/dateTimestampProvider';
export class Scheduler {
    constructor(schedulerActionCtor, now = Scheduler.now) {
        this.schedulerActionCtor = schedulerActionCtor;
        this.now = now;
    }
    schedule(work, delay = 0, state) {
        return new this.schedulerActionCtor(this, work).schedule(state, delay);
    }
}
Scheduler.now = dateTimestampProvider.now;
 çh  __webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "Scheduler": () => (/* binding */ Scheduler)
/* harmony export */ });
/* harmony import */ var _scheduler_dateTimestampProvider__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./scheduler/dateTimestampProvider */ 8205);
   ReplaceSourceOriginalSourceø“  webpack://./node_modules/@angular-devkit/build-angular/src/babel/webpack-loader.js??ruleSet[1].rules[1].use[0]!./node_modules/@ngtools/webpack/src/ivy/index.js!./node_modules/source-map-loader/dist/cjs.js??ruleSet[1].rules[2]!./node_modules/rxjs/dist/esm/internal/Scheduler.js073undefined7581undefined389413_scheduler_dateTimestampProvider__WEBPACK_IMPORTED_MODULE_0__.dateTimestampProvider.nowundefined
êëööÿÿìÂÃ   Ş  «webpack/lib/util/registerExternalSerializerœwebpack-sources/ConcatSource€«webpack/lib/util/registerExternalSerializer™webpack-sources/RawSourceD  __webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "debounceTime": () => (/* binding */ debounceTime)
/* harmony export */ });
/* harmony import */ var _scheduler_async__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../scheduler/async */ 2328);
/* harmony import */ var _util_lift__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ../util/lift */ 5191);
/* harmony import */ var _OperatorSubscriber__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ./OperatorSubscriber */ 5308);
«webpack/lib/util/registerExternalSerializerwebpack-sources/ReplaceSource«webpack/lib/util/registerExternalSerializerŸwebpack-sources/SourceMapSourceÜ  import { asyncScheduler } from '../scheduler/async';
import { operate } from '../util/lift';
import { OperatorSubscriber } from './OperatorSubscriber';
export function debounceTime(dueTime, scheduler = asyncScheduler) {
  return operate((source, subscriber) => {
    let activeTask = null;
    let lastValue = null;
    let lastTime = null;

    const emit = () => {
      if (activeTask) {
        activeTask.unsubscribe();
        activeTask = null;
        const value = lastValue;
        lastValue = null;
        subscriber.next(value);
      }
    };

    function emitWhenIdle() {
      const targetTime = lastTime + dueTime;
      const now = scheduler.now();

      if (now < targetTime) {
        activeTask = this.schedule(undefined, targetTime - now);
        subscriber.add(activeTask);
        return;
      }

      emit();
    }

    source.subscribe(new OperatorSubscriber(subscriber, value => {
      lastValue = value;
      lastTime = scheduler.now();

      if (!activeTask) {
        activeTask = scheduler.schedule(emitWhenIdle, dueTime);
        subscriber.add(activeTask);
      }
    }, () => {
      emit();
      subscriber.complete();
    }, undefined, () => {
      lastValue = activeTask = null;
    }));
  });
}!  webpack://./node_modules/@angular-devkit/build-angular/src/babel/webpack-loader.js??ruleSet[1].rules[1].use[0]!./node_modules/@ngtools/webpack/src/ivy/index.js!./node_modules/source-map-loader/dist/cjs.js??ruleSet[1].rules[2]!./node_modules/rxjs/dist/esm/internal/operators/debounceTime.jsa  {"version":3,"sources":["webpack://./node_modules/rxjs/dist/esm/internal/operators/debounceTime.js"],"names":["asyncScheduler","operate","OperatorSubscriber","debounceTime","dueTime","scheduler","source","subscriber","activeTask","lastValue","lastTime","emit","unsubscribe","value","next","emitWhenIdle","targetTime","now","schedule","undefined","add","subscribe","complete"],"mappings":"AAAA,SAASA,cAAT,QAA+B,oBAA/B;AACA,SAASC,OAAT,QAAwB,cAAxB;AACA,SAASC,kBAAT,QAAmC,sBAAnC;AACA,OAAO,SAASC,YAAT,CAAsBC,OAAtB,EAA+BC,SAAS,GAAGL,cAA3C,EAA2D;AAC9D,SAAOC,OAAO,CAAC,CAACK,MAAD,EAASC,UAAT,KAAwB;AACnC,QAAIC,UAAU,GAAG,IAAjB;AACA,QAAIC,SAAS,GAAG,IAAhB;AACA,QAAIC,QAAQ,GAAG,IAAf;;AACA,UAAMC,IAAI,GAAG,MAAM;AACf,UAAIH,UAAJ,EAAgB;AACZA,QAAAA,UAAU,CAACI,WAAX;AACAJ,QAAAA,UAAU,GAAG,IAAb;AACA,cAAMK,KAAK,GAAGJ,SAAd;AACAA,QAAAA,SAAS,GAAG,IAAZ;AACAF,QAAAA,UAAU,CAACO,IAAX,CAAgBD,KAAhB;AACH;AACJ,KARD;;AASA,aAASE,YAAT,GAAwB;AACpB,YAAMC,UAAU,GAAGN,QAAQ,GAAGN,OAA9B;AACA,YAAMa,GAAG,GAAGZ,SAAS,CAACY,GAAV,EAAZ;;AACA,UAAIA,GAAG,GAAGD,UAAV,EAAsB;AAClBR,QAAAA,UAAU,GAAG,KAAKU,QAAL,CAAcC,SAAd,EAAyBH,UAAU,GAAGC,GAAtC,CAAb;AACAV,QAAAA,UAAU,CAACa,GAAX,CAAeZ,UAAf;AACA;AACH;;AACDG,MAAAA,IAAI;AACP;;AACDL,IAAAA,MAAM,CAACe,SAAP,CAAiB,IAAInB,kBAAJ,CAAuBK,UAAvB,EAAoCM,KAAD,IAAW;AAC3DJ,MAAAA,SAAS,GAAGI,KAAZ;AACAH,MAAAA,QAAQ,GAAGL,SAAS,CAACY,GAAV,EAAX;;AACA,UAAI,CAACT,UAAL,EAAiB;AACbA,QAAAA,UAAU,GAAGH,SAAS,CAACa,QAAV,CAAmBH,YAAnB,EAAiCX,OAAjC,CAAb;AACAG,QAAAA,UAAU,CAACa,GAAX,CAAeZ,UAAf;AACH;AACJ,KAPgB,EAOd,MAAM;AACLG,MAAAA,IAAI;AACJJ,MAAAA,UAAU,CAACe,QAAX;AACH,KAVgB,EAUdH,SAVc,EAUH,MAAM;AAChBV,MAAAA,SAAS,GAAGD,UAAU,GAAG,IAAzB;AACH,KAZgB,CAAjB;AAaH,GApCa,CAAd;AAqCH","sourcesContent":["import { asyncScheduler } from '../scheduler/async';\nimport { operate } from '../util/lift';\nimport { OperatorSubscriber } from './OperatorSubscriber';\nexport function debounceTime(dueTime, scheduler = asyncScheduler) {\n    return operate((source, subscriber) => {\n        let activeTask = null;\n        let lastValue = null;\n        let lastTime = null;\n        const emit = () => {\n            if (activeTask) {\n                activeTask.unsubscribe();\n                activeTask = null;\n                const value = lastValue;\n                lastValue = null;\n                subscriber.next(value);\n            }\n        };\n        function emitWhenIdle() {\n            const targetTime = lastTime + dueTime;\n            const now = scheduler.now();\n            if (now < targetTime) {\n                activeTask = this.schedule(undefined, targetTime - now);\n                subscriber.add(activeTask);\n                return;\n            }\n            emit();\n        }\n        source.subscribe(new OperatorSubscriber(subscriber, (value) => {\n            lastValue = value;\n            lastTime = scheduler.now();\n            if (!activeTask) {\n                activeTask = scheduler.schedule(emitWhenIdle, dueTime);\n                subscriber.add(activeTask);\n            }\n        }, () => {\n            emit();\n            subscriber.complete();\n        }, undefined, () => {\n            lastValue = activeTask = null;\n        }));\n    });\n}\n"],"file":"x"} c35[]H–   ˜      Ê   ×   å   ë   h  y  €€€€¼_scheduler_async__WEBPACK_IMPORTED_MODULE_0__.asyncScheduler³(0,_util_lift__WEBPACK_IMPORTED_MODULE_1__.operate)Ã_OperatorSubscriber__WEBPACK_IMPORTED_MODULE_2__.OperatorSubscriberÈ  __webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "debounceTime": () => (/* binding */ debounceTime)
/* harmony export */ });
/* harmony import */ var _scheduler_async__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../scheduler/async */ 2328);
/* harmony import */ var _util_lift__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ../util/lift */ 5191);
/* harmony import */ var _OperatorSubscriber__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ./OperatorSubscriber */ 5308);



function debounceTime(dueTime, scheduler = _scheduler_async__WEBPACK_IMPORTED_MODULE_0__.asyncScheduler) {
  return (0,_util_lift__WEBPACK_IMPORTED_MODULE_1__.operate)((source, subscriber) => {
    let activeTask = null;
    let lastValue = null;
    let lastTime = null;

    const emit = () => {
      if (activeTask) {
        activeTask.unsubscribe();
        activeTask = null;
        const value = lastValue;
        lastValue = null;
        subscriber.next(value);
      }
    };

    function emitWhenIdle() {
      const targetTime = lastTime + dueTime;
      const now = scheduler.now();

      if (now < targetTime) {
        activeTask = this.schedule(undefined, targetTime - now);
        subscriber.add(activeTask);
        return;
      }

      emit();
    }

    source.subscribe(new _OperatorSubscriber__WEBPACK_IMPORTED_MODULE_2__.OperatorSubscriber(subscriber, value => {
      lastValue = value;
      lastTime = scheduler.now();

      if (!activeTask) {
        activeTask = scheduler.schedule(emitWhenIdle, dueTime);
        subscriber.add(activeTask);
      }
    }, () => {
      emit();
      subscriber.complete();
    }, undefined, () => {
      lastValue = activeTask = null;
    }));
  });
}ÉËÏxŸ  ;;;;;;;AAAA;AACA;AACA;AACO,SAASG,YAAT,CAAsBC,OAAtB,EAA+BC,SAAS,GAAGL,4DAA3C,EAA2D;AAC9D,SAAOC,mDAAO,CAAC,CAACK,MAAD,EAASC,UAAT,KAAwB;AACnC,QAAIC,UAAU,GAAG,IAAjB;AACA,QAAIC,SAAS,GAAG,IAAhB;AACA,QAAIC,QAAQ,GAAG,IAAf;;AACA,UAAMC,IAAI,GAAG,MAAM;AACf,UAAIH,UAAJ,EAAgB;AACZA,QAAAA,UAAU,CAACI,WAAX;AACAJ,QAAAA,UAAU,GAAG,IAAb;AACA,cAAMK,KAAK,GAAGJ,SAAd;AACAA,QAAAA,SAAS,GAAG,IAAZ;AACAF,QAAAA,UAAU,CAACO,IAAX,CAAgBD,KAAhB;AACH;AACJ,KARD;;AASA,aAASE,YAAT,GAAwB;AACpB,YAAMC,UAAU,GAAGN,QAAQ,GAAGN,OAA9B;AACA,YAAMa,GAAG,GAAGZ,SAAS,CAACY,GAAV,EAAZ;;AACA,UAAIA,GAAG,GAAGD,UAAV,EAAsB;AAClBR,QAAAA,UAAU,GAAG,KAAKU,QAAL,CAAcC,SAAd,EAAyBH,UAAU,GAAGC,GAAtC,CAAb;AACAV,QAAAA,UAAU,CAACa,GAAX,CAAeZ,UAAf;AACA;AACH;;AACDG,MAAAA,IAAI;AACP;;AACDL,IAAAA,MAAM,CAACe,SAAP,CAAiB,IAAInB,mEAAJ,CAAuBK,UAAvB,EAAoCM,KAAD,IAAW;AAC3DJ,MAAAA,SAAS,GAAGI,KAAZ;AACAH,MAAAA,QAAQ,GAAGL,SAAS,CAACY,GAAV,EAAX;;AACA,UAAI,CAACT,UAAL,EAAiB;AACbA,QAAAA,UAAU,GAAGH,SAAS,CAACa,QAAV,CAAmBH,YAAnB,EAAiCX,OAAjC,CAAb;AACAG,QAAAA,UAAU,CAACa,GAAX,CAAeZ,UAAf;AACH;AACJ,KAPgB,EAOd,MAAM;AACLG,MAAAA,IAAI;AACJJ,MAAAA,UAAU,CAACe,QAAX;AACH,KAVgB,EAUdH,SAVc,EAUH,MAAM;AAChBV,MAAAA,SAAS,GAAGD,UAAU,GAAG,IAAzB;AACH,KAZgB,CAAjB;AAaH,GApCa,CAAd;AAqCHÉwebpack://./node_modules/rxjs/dist/esm/internal/operators/debounceTime.js­  import { asyncScheduler } from '../scheduler/async';
import { operate } from '../util/lift';
import { OperatorSubscriber } from './OperatorSubscriber';
export function debounceTime(dueTime, scheduler = asyncScheduler) {
    return operate((source, subscriber) => {
        let activeTask = null;
        let lastValue = null;
        let lastTime = null;
        const emit = () => {
            if (activeTask) {
                activeTask.unsubscribe();
                activeTask = null;
                const value = lastValue;
                lastValue = null;
                subscriber.next(value);
            }
        };
        function emitWhenIdle() {
            const targetTime = lastTime + dueTime;
            const now = scheduler.now();
            if (now < targetTime) {
                activeTask = this.schedule(undefined, targetTime - now);
                subscriber.add(activeTask);
                return;
            }
            emit();
        }
        source.subscribe(new OperatorSubscriber(subscriber, (value) => {
            lastValue = value;
            lastTime = scheduler.now();
            if (!activeTask) {
                activeTask = scheduler.schedule(emitWhenIdle, dueTime);
                subscriber.add(activeTask);
            }
        }, () => {
            emit();
            subscriber.complete();
        }, undefined, () => {
            lastValue = activeTask = null;
        }));
    });
}
`Ò‡operate’OperatorSubscriber÷ÿÿ‡dueTime‰scheduler»ŠsubscriberŠactiveTask‰lastValueˆlastTime„emit‹unsubscribe…value„nextŒemitWhenIdleŠtargetTimeƒnowˆschedule‰undefinedƒadd‰subscribeˆcompleteÀD  __webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "debounceTime": () => (/* binding */ debounceTime)
/* harmony export */ });
/* harmony import */ var _scheduler_async__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../scheduler/async */ 2328);
/* harmony import */ var _util_lift__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ../util/lift */ 5191);
/* harmony import */ var _OperatorSubscriber__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ./OperatorSubscriber */ 5308);
ÁÜ  import { asyncScheduler } from '../scheduler/async';
import { operate } from '../util/lift';
import { OperatorSubscriber } from './OperatorSubscriber';
export function debounceTime(dueTime, scheduler = asyncScheduler) {
  return operate((source, subscriber) => {
    let activeTask = null;
    let lastValue = null;
    let lastTime = null;

    const emit = () => {
      if (activeTask) {
        activeTask.unsubscribe();
        activeTask = null;
        const value = lastValue;
        lastValue = null;
        subscriber.next(value);
      }
    };

    function emitWhenIdle() {
      const targetTime = lastTime + dueTime;
      const now = scheduler.now();

      if (now < targetTime) {
        activeTask = this.schedule(undefined, targetTime - now);
        subscriber.add(activeTask);
        return;
      }

      emit();
    }

    source.subscribe(new OperatorSubscriber(subscriber, value => {
      lastValue = value;
      lastTime = scheduler.now();

      if (!activeTask) {
        activeTask = scheduler.schedule(emitWhenIdle, dueTime);
        subscriber.add(activeTask);
      }
    }, () => {
      emit();
      subscriber.complete();
    }, undefined, () => {
      lastValue = activeTask = null;
    }));
  });
}a  {"version":3,"sources":["webpack://./node_modules/rxjs/dist/esm/internal/operators/debounceTime.js"],"names":["asyncScheduler","operate","OperatorSubscriber","debounceTime","dueTime","scheduler","source","subscriber","activeTask","lastValue","lastTime","emit","unsubscribe","value","next","emitWhenIdle","targetTime","now","schedule","undefined","add","subscribe","complete"],"mappings":"AAAA,SAASA,cAAT,QAA+B,oBAA/B;AACA,SAASC,OAAT,QAAwB,cAAxB;AACA,SAASC,kBAAT,QAAmC,sBAAnC;AACA,OAAO,SAASC,YAAT,CAAsBC,OAAtB,EAA+BC,SAAS,GAAGL,cAA3C,EAA2D;AAC9D,SAAOC,OAAO,CAAC,CAACK,MAAD,EAASC,UAAT,KAAwB;AACnC,QAAIC,UAAU,GAAG,IAAjB;AACA,QAAIC,SAAS,GAAG,IAAhB;AACA,QAAIC,QAAQ,GAAG,IAAf;;AACA,UAAMC,IAAI,GAAG,MAAM;AACf,UAAIH,UAAJ,EAAgB;AACZA,QAAAA,UAAU,CAACI,WAAX;AACAJ,QAAAA,UAAU,GAAG,IAAb;AACA,cAAMK,KAAK,GAAGJ,SAAd;AACAA,QAAAA,SAAS,GAAG,IAAZ;AACAF,QAAAA,UAAU,CAACO,IAAX,CAAgBD,KAAhB;AACH;AACJ,KARD;;AASA,aAASE,YAAT,GAAwB;AACpB,YAAMC,UAAU,GAAGN,QAAQ,GAAGN,OAA9B;AACA,YAAMa,GAAG,GAAGZ,SAAS,CAACY,GAAV,EAAZ;;AACA,UAAIA,GAAG,GAAGD,UAAV,EAAsB;AAClBR,QAAAA,UAAU,GAAG,KAAKU,QAAL,CAAcC,SAAd,EAAyBH,UAAU,GAAGC,GAAtC,CAAb;AACAV,QAAAA,UAAU,CAACa,GAAX,CAAeZ,UAAf;AACA;AACH;;AACDG,MAAAA,IAAI;AACP;;AACDL,IAAAA,MAAM,CAACe,SAAP,CAAiB,IAAInB,kBAAJ,CAAuBK,UAAvB,EAAoCM,KAAD,IAAW;AAC3DJ,MAAAA,SAAS,GAAGI,KAAZ;AACAH,MAAAA,QAAQ,GAAGL,SAAS,CAACY,GAAV,EAAX;;AACA,UAAI,CAACT,UAAL,EAAiB;AACbA,QAAAA,UAAU,GAAGH,SAAS,CAACa,QAAV,CAAmBH,YAAnB,EAAiCX,OAAjC,CAAb;AACAG,QAAAA,UAAU,CAACa,GAAX,CAAeZ,UAAf;AACH;AACJ,KAPgB,EAOd,MAAM;AACLG,MAAAA,IAAI;AACJJ,MAAAA,UAAU,CAACe,QAAX;AACH,KAVgB,EAUdH,SAVc,EAUH,MAAM;AAChBV,MAAAA,SAAS,GAAGD,UAAU,GAAG,IAAzB;AACH,KAZgB,CAAjB;AAaH,GApCa,CAAd;AAqCH","sourcesContent":["import { asyncScheduler } from '../scheduler/async';\nimport { operate } from '../util/lift';\nimport { OperatorSubscriber } from './OperatorSubscriber';\nexport function debounceTime(dueTime, scheduler = asyncScheduler) {\n    return operate((source, subscriber) => {\n        let activeTask = null;\n        let lastValue = null;\n        let lastTime = null;\n        const emit = () => {\n            if (activeTask) {\n                activeTask.unsubscribe();\n                activeTask = null;\n                const value = lastValue;\n                lastValue = null;\n                subscriber.next(value);\n            }\n        };\n        function emitWhenIdle() {\n            const targetTime = lastTime + dueTime;\n            const now = scheduler.now();\n            if (now < targetTime) {\n                activeTask = this.schedule(undefined, targetTime - now);\n                subscriber.add(activeTask);\n                return;\n            }\n            emit();\n        }\n        source.subscribe(new OperatorSubscriber(subscriber, (value) => {\n            lastValue = value;\n            lastTime = scheduler.now();\n            if (!activeTask) {\n                activeTask = scheduler.schedule(emitWhenIdle, dueTime);\n                subscriber.add(activeTask);\n            }\n        }, () => {\n            emit();\n            subscriber.complete();\n        }, undefined, () => {\n            lastValue = activeTask = null;\n        }));\n    });\n}\n"],"file":"x"}  false051undefined5391undefined93150undefined152158undefined202215_scheduler_async__WEBPACK_IMPORTED_MODULE_0__.asyncSchedulerundefined229235(0,_util_lift__WEBPACK_IMPORTED_MODULE_1__.operate)undefined872889_OperatorSubscriber__WEBPACK_IMPORTED_MODULE_2__.OperatorSubscriberundefined
ÂÃÎöÿÿÄš›   À  «webpack/lib/util/registerExternalSerializerœwebpack-sources/ConcatSource€«webpack/lib/util/registerExternalSerializer™webpack-sources/RawSourceO  __webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "distinctUntilChanged": () => (/* binding */ distinctUntilChanged)
/* harmony export */ });
/* harmony import */ var _util_identity__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../util/identity */ 713);
/* harmony import */ var _util_lift__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ../util/lift */ 5191);
/* harmony import */ var _OperatorSubscriber__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ./OperatorSubscriber */ 5308);
«webpack/lib/util/registerExternalSerializerwebpack-sources/ReplaceSource«webpack/lib/util/registerExternalSerializerwebpack-sources/OriginalSource!  import { identity } from '../util/identity';
import { operate } from '../util/lift';
import { OperatorSubscriber } from './OperatorSubscriber';
export function distinctUntilChanged(comparator, keySelector = identity) {
    comparator = comparator !== null && comparator !== void 0 ? comparator : defaultCompare;
    return operate((source, subscriber) => {
        let previousKey;
        let first = true;
        source.subscribe(new OperatorSubscriber(subscriber, (value) => {
            const currentKey = keySelector(value);
            if (first || !comparator(previousKey, currentKey)) {
                first = false;
                previousKey = currentKey;
                subscriber.next(value);
            }
        }));
    });
}
function defaultCompare(a, b) {
    return a === b;
}
)  webpack://./node_modules/@angular-devkit/build-angular/src/babel/webpack-loader.js??ruleSet[1].rules[1].use[0]!./node_modules/@ngtools/webpack/src/ivy/index.js!./node_modules/source-map-loader/dist/cjs.js??ruleSet[1].rules[2]!./node_modules/rxjs/dist/esm/internal/operators/distinctUntilChanged.js c+-SUH      –   Ï   Ö   C  I  µ  Æ  €€€€´_util_identity__WEBPACK_IMPORTED_MODULE_0__.identity³(0,_util_lift__WEBPACK_IMPORTED_MODULE_1__.operate)Ã_OperatorSubscriber__WEBPACK_IMPORTED_MODULE_2__.OperatorSubscriber e  __webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "distinctUntilChanged": () => (/* binding */ distinctUntilChanged)
/* harmony export */ });
/* harmony import */ var _util_identity__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../util/identity */ 713);
/* harmony import */ var _util_lift__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ../util/lift */ 5191);
/* harmony import */ var _OperatorSubscriber__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ./OperatorSubscriber */ 5308);



function distinctUntilChanged(comparator, keySelector = _util_identity__WEBPACK_IMPORTED_MODULE_0__.identity) {
    comparator = comparator !== null && comparator !== void 0 ? comparator : defaultCompare;
    return (0,_util_lift__WEBPACK_IMPORTED_MODULE_1__.operate)((source, subscriber) => {
        let previousKey;
        let first = true;
        source.subscribe(new _OperatorSubscriber__WEBPACK_IMPORTED_MODULE_2__.OperatorSubscriber(subscriber, (value) => {
            const currentKey = keySelector(value);
            if (first || !comparator(previousKey, currentKey)) {
                first = false;
                previousKey = currentKey;
                subscriber.next(value);
            }
        }));
    });
}
function defaultCompare(a, b) {
    return a === b;
}
¡£§x¥   ;;;;;;;AAA4C;AACL;AACmB;AACnD,wDAAwD,oDAAQ;AACvE;AACA,WAAW,mDAAO;AAClB;AACA;AACA,6BAA6B,mEAAkB;AAC/C;AACA;AACA;AACA;AACA;AACA;AACA,SAAS;AACT,KAAK;AACL;AACA;AACA;AACA)  webpack://./node_modules/@angular-devkit/build-angular/src/babel/webpack-loader.js??ruleSet[1].rules[1].use[0]!./node_modules/@ngtools/webpack/src/ivy/index.js!./node_modules/source-map-loader/dist/cjs.js??ruleSet[1].rules[2]!./node_modules/rxjs/dist/esm/internal/operators/distinctUntilChanged.js!  import { identity } from '../util/identity';
import { operate } from '../util/lift';
import { OperatorSubscriber } from './OperatorSubscriber';
export function distinctUntilChanged(comparator, keySelector = identity) {
    comparator = comparator !== null && comparator !== void 0 ? comparator : defaultCompare;
    return operate((source, subscriber) => {
        let previousKey;
        let first = true;
        source.subscribe(new OperatorSubscriber(subscriber, (value) => {
            const currentKey = keySelector(value);
            if (first || !comparator(previousKey, currentKey)) {
                first = false;
                previousKey = currentKey;
                subscriber.next(value);
            }
        }));
    });
}
function defaultCompare(a, b) {
    return a === b;
}
 ¬O  __webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "distinctUntilChanged": () => (/* binding */ distinctUntilChanged)
/* harmony export */ });
/* harmony import */ var _util_identity__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../util/identity */ 713);
/* harmony import */ var _util_lift__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ../util/lift */ 5191);
/* harmony import */ var _OperatorSubscriber__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ./OperatorSubscriber */ 5308);
Åù6  webpack://./node_modules/@angular-devkit/build-angular/src/babel/webpack-loader.js??ruleSet[1].rules[1].use[0]!./node_modules/@ngtools/webpack/src/ivy/index.js!./node_modules/source-map-loader/dist/cjs.js??ruleSet[1].rules[2]!./node_modules/rxjs/dist/esm/internal/operators/distinctUntilChanged.js043undefined4583undefined85142undefined144150undefined207214_util_identity__WEBPACK_IMPORTED_MODULE_0__.identityundefined323329(0,_util_lift__WEBPACK_IMPORTED_MODULE_1__.operate)undefined437454_OperatorSubscriber__WEBPACK_IMPORTED_MODULE_2__.OperatorSubscriberundefined
°±¼öÿÿ²ˆ‰   9  «webpack/lib/util/registerExternalSerializerœwebpack-sources/ConcatSource€«webpack/lib/util/registerExternalSerializer™webpack-sources/RawSource,  __webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "skip": () => (/* binding */ skip)
/* harmony export */ });
/* harmony import */ var _filter__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./filter */ 1569);
«webpack/lib/util/registerExternalSerializerwebpack-sources/ReplaceSource«webpack/lib/util/registerExternalSerializerwebpack-sources/OriginalSourcet   import { filter } from './filter';
export function skip(count) {
    return filter((_, index) => count <= index);
}
  webpack://./node_modules/@angular-devkit/build-angular/src/babel/webpack-loader.js??ruleSet[1].rules[1].use[0]!./node_modules/@ngtools/webpack/src/ivy/index.js!./node_modules/source-map-loader/dist/cjs.js??ruleSet[1].rules[2]!./node_modules/rxjs/dist/esm/internal/operators/skip.js d!#)LQ€€¯(0,_filter__WEBPACK_IMPORTED_MODULE_0__.filter)   __webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "skip": () => (/* binding */ skip)
/* harmony export */ });
/* harmony import */ var _filter__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./filter */ 1569);

function skip(count) {
    return (0,_filter__WEBPACK_IMPORTED_MODULE_0__.filter)((_, index) => count <= index);
}
‘•x&   ;;;;;AAAkC;AAC3B;AACP,WAAW,+CAAM;AACjB  webpack://./node_modules/@angular-devkit/build-angular/src/babel/webpack-loader.js??ruleSet[1].rules[1].use[0]!./node_modules/@ngtools/webpack/src/ivy/index.js!./node_modules/source-map-loader/dist/cjs.js??ruleSet[1].rules[2]!./node_modules/rxjs/dist/esm/internal/operators/skip.jst   import { filter } from './filter';
export function skip(count) {
    return filter((_, index) => count <= index);
}
 š,  __webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "skip": () => (/* binding */ skip)
/* harmony export */ });
/* harmony import */ var _filter__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./filter */ 1569);
³ùn  webpack://./node_modules/@angular-devkit/build-angular/src/babel/webpack-loader.js??ruleSet[1].rules[1].use[0]!./node_modules/@ngtools/webpack/src/ivy/index.js!./node_modules/source-map-loader/dist/cjs.js??ruleSet[1].rules[2]!./node_modules/rxjs/dist/esm/internal/operators/skip.js033undefined3541undefined7681(0,_filter__WEBPACK_IMPORTED_MODULE_0__.filter)undefined
Ÿªöÿÿ vÿÿÿwÿÿÿ     «webpack/lib/util/registerExternalSerializerœwebpack-sources/ConcatSource€«webpack/lib/util/registerExternalSerializer™webpack-sources/RawSourceº  __webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "takeUntil": () => (/* binding */ takeUntil)
/* harmony export */ });
/* harmony import */ var _util_lift__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../util/lift */ 5191);
/* harmony import */ var _OperatorSubscriber__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ./OperatorSubscriber */ 5308);
/* harmony import */ var _observable_innerFrom__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ../observable/innerFrom */ 3957);
/* harmony import */ var _util_noop__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! ../util/noop */ 1074);
«webpack/lib/util/registerExternalSerializerwebpack-sources/ReplaceSource«webpack/lib/util/registerExternalSerializerwebpack-sources/OriginalSourceÄ  import { operate } from '../util/lift';
import { OperatorSubscriber } from './OperatorSubscriber';
import { innerFrom } from '../observable/innerFrom';
import { noop } from '../util/noop';
export function takeUntil(notifier) {
    return operate((source, subscriber) => {
        innerFrom(notifier).subscribe(new OperatorSubscriber(subscriber, () => subscriber.complete(), noop));
        !subscriber.closed && source.subscribe(subscriber);
    });
}
  webpack://./node_modules/@angular-devkit/build-angular/src/babel/webpack-loader.js??ruleSet[1].rules[1].use[0]!./node_modules/@ngtools/webpack/src/ivy/index.js!./node_modules/source-map-loader/dist/cjs.js??ruleSet[1].rules[2]!./node_modules/rxjs/dist/esm/internal/operators/takeUntil.js	 c&(acL–   ˜   »   ½   Ã   î   ô        :  K  v  y  €€€€€³(0,_util_lift__WEBPACK_IMPORTED_MODULE_0__.operate)À(0,_observable_innerFrom__WEBPACK_IMPORTED_MODULE_1__.innerFrom)Ã_OperatorSubscriber__WEBPACK_IMPORTED_MODULE_2__.OperatorSubscriber¬_util_noop__WEBPACK_IMPORTED_MODULE_3__.noop|ÿÿÿz  __webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "takeUntil": () => (/* binding */ takeUntil)
/* harmony export */ });
/* harmony import */ var _util_lift__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../util/lift */ 5191);
/* harmony import */ var _OperatorSubscriber__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ./OperatorSubscriber */ 5308);
/* harmony import */ var _observable_innerFrom__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ../observable/innerFrom */ 3957);
/* harmony import */ var _util_noop__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! ../util/noop */ 1074);




function takeUntil(notifier) {
    return (0,_util_lift__WEBPACK_IMPORTED_MODULE_0__.operate)((source, subscriber) => {
        (0,_observable_innerFrom__WEBPACK_IMPORTED_MODULE_1__.innerFrom)(notifier).subscribe(new _OperatorSubscriber__WEBPACK_IMPORTED_MODULE_2__.OperatorSubscriber(subscriber, () => subscriber.complete(), _util_noop__WEBPACK_IMPORTED_MODULE_3__.noop));
        !subscriber.closed && source.subscribe(subscriber);
    });
}
}ÿÿÿÿÿÿƒxu   ;;;;;;;;AAAuC;AACmB;AACN;AAChB;AAC7B;AACP,WAAW,mDAAO;AAClB,QAAQ,gEAAS,yBAAyB,mEAAkB,0CAA0C,4CAAI;AAC1G;AACA,KAAK;AACL  webpack://./node_modules/@angular-devkit/build-angular/src/babel/webpack-loader.js??ruleSet[1].rules[1].use[0]!./node_modules/@ngtools/webpack/src/ivy/index.js!./node_modules/source-map-loader/dist/cjs.js??ruleSet[1].rules[2]!./node_modules/rxjs/dist/esm/internal/operators/takeUntil.jsÄ  import { operate } from '../util/lift';
import { OperatorSubscriber } from './OperatorSubscriber';
import { innerFrom } from '../observable/innerFrom';
import { noop } from '../util/noop';
export function takeUntil(notifier) {
    return operate((source, subscriber) => {
        innerFrom(notifier).subscribe(new OperatorSubscriber(subscriber, () => subscriber.complete(), noop));
        !subscriber.closed && source.subscribe(subscriber);
    });
}
 ˆº  __webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "takeUntil": () => (/* binding */ takeUntil)
/* harmony export */ });
/* harmony import */ var _util_lift__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../util/lift */ 5191);
/* harmony import */ var _OperatorSubscriber__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ./OperatorSubscriber */ 5308);
/* harmony import */ var _observable_innerFrom__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ../observable/innerFrom */ 3957);
/* harmony import */ var _util_noop__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! ../util/noop */ 1074);
¡ù  webpack://./node_modules/@angular-devkit/build-angular/src/babel/webpack-loader.js??ruleSet[1].rules[1].use[0]!./node_modules/@ngtools/webpack/src/ivy/index.js!./node_modules/source-map-loader/dist/cjs.js??ruleSet[1].rules[2]!./node_modules/rxjs/dist/esm/internal/operators/takeUntil.js038undefined4097undefined99150undefined152187undefined189195undefined238244(0,_util_lift__WEBPACK_IMPORTED_MODULE_0__.operate)undefined280288(0,_observable_innerFrom__WEBPACK_IMPORTED_MODULE_1__.innerFrom)undefined314331_OperatorSubscriber__WEBPACK_IMPORTED_MODULE_2__.OperatorSubscriberundefined374377_util_noop__WEBPACK_IMPORTED_MODULE_3__.noopundefined
Œ˜öÿÿdÿÿÿeÿÿÿ   ê  «webpack/lib/util/registerExternalSerializerœwebpack-sources/ConcatSource€«webpack/lib/util/registerExternalSerializer™webpack-sources/RawSourceã   __webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "dateTimestampProvider": () => (/* binding */ dateTimestampProvider)
/* harmony export */ });
«webpack/lib/util/registerExternalSerializerwebpack-sources/ReplaceSource«webpack/lib/util/registerExternalSerializerwebpack-sources/OriginalSource•   export const dateTimestampProvider = {
    now() {
        return (dateTimestampProvider.delegate || Date).now();
    },
    delegate: undefined,
};
*  webpack://./node_modules/@angular-devkit/build-angular/src/babel/webpack-loader.js??ruleSet[1].rules[1].use[0]!./node_modules/@ngtools/webpack/src/ivy/index.js!./node_modules/source-map-loader/dist/cjs.js??ruleSet[1].rules[2]!./node_modules/rxjs/dist/esm/internal/scheduler/dateTimestampProvider.js €jÿÿÿq  __webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "dateTimestampProvider": () => (/* binding */ dateTimestampProvider)
/* harmony export */ });
const dateTimestampProvider = {
    now() {
        return (dateTimestampProvider.delegate || Date).now();
    },
    delegate: undefined,
};
kÿÿÿmÿÿÿqÿÿÿx&   ;;;;AAAO;AACP;AACA;AACA,KAAK;AACL;AACA*  webpack://./node_modules/@angular-devkit/build-angular/src/babel/webpack-loader.js??ruleSet[1].rules[1].use[0]!./node_modules/@ngtools/webpack/src/ivy/index.js!./node_modules/source-map-loader/dist/cjs.js??ruleSet[1].rules[2]!./node_modules/rxjs/dist/esm/internal/scheduler/dateTimestampProvider.js•   export const dateTimestampProvider = {
    now() {
        return (dateTimestampProvider.delegate || Date).now();
    },
    delegate: undefined,
};
 vÿÿÿã   __webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "dateTimestampProvider": () => (/* binding */ dateTimestampProvider)
/* harmony export */ });
ù5  webpack://./node_modules/@angular-devkit/build-angular/src/babel/webpack-loader.js??ruleSet[1].rules[1].use[0]!./node_modules/@ngtools/webpack/src/ivy/index.js!./node_modules/source-map-loader/dist/cjs.js??ruleSet[1].rules[2]!./node_modules/rxjs/dist/esm/internal/scheduler/dateTimestampProvider.js06undefined
{ÿÿÿ†öÿÿ|ÿÿÿRÿÿÿSÿÿÿ   ^  «webpack/lib/util/registerExternalSerializerœwebpack-sources/ConcatSource€«webpack/lib/util/registerExternalSerializer™webpack-sources/RawSource5  __webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "AsyncAction": () => (/* binding */ AsyncAction)
/* harmony export */ });
/* harmony import */ var _Action__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./Action */ 3332);
/* harmony import */ var _intervalProvider__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ./intervalProvider */ 9446);
/* harmony import */ var _util_arrRemove__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ../util/arrRemove */ 3241);
«webpack/lib/util/registerExternalSerializerwebpack-sources/ReplaceSource«webpack/lib/util/registerExternalSerializerwebpack-sources/OriginalSource…	  import { Action } from './Action';
import { intervalProvider } from './intervalProvider';
import { arrRemove } from '../util/arrRemove';
export class AsyncAction extends Action {
    constructor(scheduler, work) {
        super(scheduler, work);
        this.scheduler = scheduler;
        this.work = work;
        this.pending = false;
    }
    schedule(state, delay = 0) {
        if (this.closed) {
            return this;
        }
        this.state = state;
        const id = this.id;
        const scheduler = this.scheduler;
        if (id != null) {
            this.id = this.recycleAsyncId(scheduler, id, delay);
        }
        this.pending = true;
        this.delay = delay;
        this.id = this.id || this.requestAsyncId(scheduler, this.id, delay);
        return this;
    }
    requestAsyncId(scheduler, _id, delay = 0) {
        return intervalProvider.setInterval(scheduler.flush.bind(scheduler, this), delay);
    }
    recycleAsyncId(_scheduler, id, delay = 0) {
        if (delay != null && this.delay === delay && this.pending === false) {
            return id;
        }
        intervalProvider.clearInterval(id);
        return undefined;
    }
    execute(state, delay) {
        if (this.closed) {
            return new Error('executing a cancelled action');
        }
        this.pending = false;
        const error = this._execute(state, delay);
        if (error) {
            return error;
        }
        else if (this.pending === false && this.id != null) {
            this.id = this.recycleAsyncId(this.scheduler, this.id, null);
        }
    }
    _execute(state, _delay) {
        let errored = false;
        let errorValue;
        try {
            this.work(state);
        }
        catch (e) {
            errored = true;
            errorValue = e ? e : new Error('Scheduled action threw falsy error');
        }
        if (errored) {
            this.unsubscribe();
            return errorValue;
        }
    }
    unsubscribe() {
        if (!this.closed) {
            const { id, scheduler } = this;
            const { actions } = scheduler;
            this.work = this.state = this.scheduler = null;
            this.pending = false;
            arrRemove(actions, this);
            if (id != null) {
                this.id = this.recycleAsyncId(scheduler, id, null);
            }
            this.delay = null;
            super.unsubscribe();
        }
    }
}
   webpack://./node_modules/@angular-devkit/build-angular/src/babel/webpack-loader.js??ruleSet[1].rules[1].use[0]!./node_modules/@ngtools/webpack/src/ivy/index.js!./node_modules/source-map-loader/dist/cjs.js??ruleSet[1].rules[2]!./node_modules/rxjs/dist/esm/internal/scheduler/AsyncAction.js c!#XZJ‡   ‰      ª   ¯   ^  y  X  u  ©  ±  €€€€«_Action__WEBPACK_IMPORTED_MODULE_0__.ActionË_intervalProvider__WEBPACK_IMPORTED_MODULE_1__.intervalProvider.setIntervalÍ_intervalProvider__WEBPACK_IMPORTED_MODULE_1__.intervalProvider.clearIntervalº(0,_util_arrRemove__WEBPACK_IMPORTED_MODULE_2__.arrRemove)Xÿÿÿá  __webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "AsyncAction": () => (/* binding */ AsyncAction)
/* harmony export */ });
/* harmony import */ var _Action__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./Action */ 3332);
/* harmony import */ var _intervalProvider__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ./intervalProvider */ 9446);
/* harmony import */ var _util_arrRemove__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ../util/arrRemove */ 3241);



class AsyncAction extends _Action__WEBPACK_IMPORTED_MODULE_0__.Action {
    constructor(scheduler, work) {
        super(scheduler, work);
        this.scheduler = scheduler;
        this.work = work;
        this.pending = false;
    }
    schedule(state, delay = 0) {
        if (this.closed) {
            return this;
        }
        this.state = state;
        const id = this.id;
        const scheduler = this.scheduler;
        if (id != null) {
            this.id = this.recycleAsyncId(scheduler, id, delay);
        }
        this.pending = true;
        this.delay = delay;
        this.id = this.id || this.requestAsyncId(scheduler, this.id, delay);
        return this;
    }
    requestAsyncId(scheduler, _id, delay = 0) {
        return _intervalProvider__WEBPACK_IMPORTED_MODULE_1__.intervalProvider.setInterval(scheduler.flush.bind(scheduler, this), delay);
    }
    recycleAsyncId(_scheduler, id, delay = 0) {
        if (delay != null && this.delay === delay && this.pending === false) {
            return id;
        }
        _intervalProvider__WEBPACK_IMPORTED_MODULE_1__.intervalProvider.clearInterval(id);
        return undefined;
    }
    execute(state, delay) {
        if (this.closed) {
            return new Error('executing a cancelled action');
        }
        this.pending = false;
        const error = this._execute(state, delay);
        if (error) {
            return error;
        }
        else if (this.pending === false && this.id != null) {
            this.id = this.recycleAsyncId(this.scheduler, this.id, null);
        }
    }
    _execute(state, _delay) {
        let errored = false;
        let errorValue;
        try {
            this.work(state);
        }
        catch (e) {
            errored = true;
            errorValue = e ? e : new Error('Scheduled action threw falsy error');
        }
        if (errored) {
            this.unsubscribe();
            return errorValue;
        }
    }
    unsubscribe() {
        if (!this.closed) {
            const { id, scheduler } = this;
            const { actions } = scheduler;
            this.work = this.state = this.scheduler = null;
            this.pending = false;
            (0,_util_arrRemove__WEBPACK_IMPORTED_MODULE_2__.arrRemove)(actions, this);
            if (id != null) {
                this.id = this.recycleAsyncId(scheduler, id, null);
            }
            this.delay = null;
            super.unsubscribe();
        }
    }
}
Yÿÿÿ[ÿÿÿ_ÿÿÿxß  ;;;;;;;AAAkC;AACoB;AACR;AACvC,0BAA0B,2CAAM;AACvC;AACA;AACA;AACA;AACA;AACA;AACA;AACA;AACA;AACA;AACA;AACA;AACA;AACA;AACA;AACA;AACA;AACA;AACA;AACA;AACA;AACA;AACA,eAAe,2EAA4B;AAC3C;AACA;AACA;AACA;AACA;AACA,QAAQ,6EAA8B;AACtC;AACA;AACA;AACA;AACA;AACA;AACA;AACA;AACA;AACA;AACA;AACA;AACA;AACA;AACA;AACA;AACA;AACA;AACA;AACA;AACA;AACA;AACA;AACA;AACA;AACA;AACA;AACA;AACA;AACA;AACA;AACA;AACA,oBAAoB,gBAAgB;AACpC,oBAAoB,UAAU;AAC9B;AACA;AACA,YAAY,0DAAS;AACrB;AACA;AACA;AACA;AACA;AACA;AACA;AACA   webpack://./node_modules/@angular-devkit/build-angular/src/babel/webpack-loader.js??ruleSet[1].rules[1].use[0]!./node_modules/@ngtools/webpack/src/ivy/index.js!./node_modules/source-map-loader/dist/cjs.js??ruleSet[1].rules[2]!./node_modules/rxjs/dist/esm/internal/scheduler/AsyncAction.js…	  import { Action } from './Action';
import { intervalProvider } from './intervalProvider';
import { arrRemove } from '../util/arrRemove';
export class AsyncAction extends Action {
    constructor(scheduler, work) {
        super(scheduler, work);
        this.scheduler = scheduler;
        this.work = work;
        this.pending = false;
    }
    schedule(state, delay = 0) {
        if (this.closed) {
            return this;
        }
        this.state = state;
        const id = this.id;
        const scheduler = this.scheduler;
        if (id != null) {
            this.id = this.recycleAsyncId(scheduler, id, delay);
        }
        this.pending = true;
        this.delay = delay;
        this.id = this.id || this.requestAsyncId(scheduler, this.id, delay);
        return this;
    }
    requestAsyncId(scheduler, _id, delay = 0) {
        return intervalProvider.setInterval(scheduler.flush.bind(scheduler, this), delay);
    }
    recycleAsyncId(_scheduler, id, delay = 0) {
        if (delay != null && this.delay === delay && this.pending === false) {
            return id;
        }
        intervalProvider.clearInterval(id);
        return undefined;
    }
    execute(state, delay) {
        if (this.closed) {
            return new Error('executing a cancelled action');
        }
        this.pending = false;
        const error = this._execute(state, delay);
        if (error) {
            return error;
        }
        else if (this.pending === false && this.id != null) {
            this.id = this.recycleAsyncId(this.scheduler, this.id, null);
        }
    }
    _execute(state, _delay) {
        let errored = false;
        let errorValue;
        try {
            this.work(state);
        }
        catch (e) {
            errored = true;
            errorValue = e ? e : new Error('Scheduled action threw falsy error');
        }
        if (errored) {
            this.unsubscribe();
            return errorValue;
        }
    }
    unsubscribe() {
        if (!this.closed) {
            const { id, scheduler } = this;
            const { actions } = scheduler;
            this.work = this.state = this.scheduler = null;
            this.pending = false;
            arrRemove(actions, this);
            if (id != null) {
                this.id = this.recycleAsyncId(scheduler, id, null);
            }
            this.delay = null;
            super.unsubscribe();
        }
    }
}
 dÿÿÿ5  __webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "AsyncAction": () => (/* binding */ AsyncAction)
/* harmony export */ });
/* harmony import */ var _Action__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./Action */ 3332);
/* harmony import */ var _intervalProvider__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ./intervalProvider */ 9446);
/* harmony import */ var _util_arrRemove__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ../util/arrRemove */ 3241);
}ÿÿÿù“  webpack://./node_modules/@angular-devkit/build-angular/src/babel/webpack-loader.js??ruleSet[1].rules[1].use[0]!./node_modules/@ngtools/webpack/src/ivy/index.js!./node_modules/source-map-loader/dist/cjs.js??ruleSet[1].rules[2]!./node_modules/rxjs/dist/esm/internal/scheduler/AsyncAction.js033undefined3588undefined90135undefined137143undefined170175_Action__WEBPACK_IMPORTED_MODULE_0__.Actionundefined862889_intervalProvider__WEBPACK_IMPORTED_MODULE_1__.intervalProvider.setIntervalundefined11121141_intervalProvider__WEBPACK_IMPORTED_MODULE_1__.intervalProvider.clearIntervalundefined22172225(0,_util_arrRemove__WEBPACK_IMPORTED_MODULE_2__.arrRemove)undefined
hÿÿÿiÿÿÿtöÿÿjÿÿÿ@ÿÿÿAÿÿÿ   t  «webpack/lib/util/registerExternalSerializerœwebpack-sources/ConcatSource€«webpack/lib/util/registerExternalSerializer™webpack-sources/RawSourceG  __webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "AsyncScheduler": () => (/* binding */ AsyncScheduler)
/* harmony export */ });
/* harmony import */ var _Scheduler__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../Scheduler */ 2604);
«webpack/lib/util/registerExternalSerializerwebpack-sources/ReplaceSource«webpack/lib/util/registerExternalSerializerwebpack-sources/OriginalSourceH  import { Scheduler } from '../Scheduler';
export class AsyncScheduler extends Scheduler {
    constructor(SchedulerAction, now = Scheduler.now) {
        super(SchedulerAction, now);
        this.actions = [];
        this._active = false;
        this._scheduled = undefined;
    }
    flush(action) {
        const { actions } = this;
        if (this._active) {
            actions.push(action);
            return;
        }
        let error;
        this._active = true;
        do {
            if ((error = action.execute(action.state, action.delay))) {
                break;
            }
        } while ((action = actions.shift()));
        this._active = false;
        if (error) {
            while ((action = actions.shift())) {
                action.unsubscribe();
            }
            throw error;
        }
    }
}
#  webpack://./node_modules/@angular-devkit/build-angular/src/babel/webpack-loader.js??ruleSet[1].rules[1].use[0]!./node_modules/@ngtools/webpack/src/ivy/index.js!./node_modules/source-map-loader/dist/cjs.js??ruleSet[1].rules[2]!./node_modules/rxjs/dist/esm/internal/scheduler/AsyncScheduler.js d(*0NVA      €€±_Scheduler__WEBPACK_IMPORTED_MODULE_0__.Schedulerµ_Scheduler__WEBPACK_IMPORTED_MODULE_0__.Scheduler.nowFÿÿÿ¯  __webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "AsyncScheduler": () => (/* binding */ AsyncScheduler)
/* harmony export */ });
/* harmony import */ var _Scheduler__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../Scheduler */ 2604);

class AsyncScheduler extends _Scheduler__WEBPACK_IMPORTED_MODULE_0__.Scheduler {
    constructor(SchedulerAction, now = _Scheduler__WEBPACK_IMPORTED_MODULE_0__.Scheduler.now) {
        super(SchedulerAction, now);
        this.actions = [];
        this._active = false;
        this._scheduled = undefined;
    }
    flush(action) {
        const { actions } = this;
        if (this._active) {
            actions.push(action);
            return;
        }
        let error;
        this._active = true;
        do {
            if ((error = action.execute(action.state, action.delay))) {
                break;
            }
        } while ((action = actions.shift()));
        this._active = false;
        if (error) {
            while ((action = actions.shift())) {
                action.unsubscribe();
            }
            throw error;
        }
    }
}
GÿÿÿIÿÿÿMÿÿÿxÊ   ;;;;;AAAyC;AAClC,6BAA6B,iDAAS;AAC7C,uCAAuC,qDAAa;AACpD;AACA;AACA;AACA;AACA;AACA;AACA,gBAAgB,UAAU;AAC1B;AACA;AACA;AACA;AACA;AACA;AACA;AACA;AACA;AACA;AACA,UAAU;AACV;AACA;AACA;AACA;AACA;AACA;AACA;AACA;AACA#  webpack://./node_modules/@angular-devkit/build-angular/src/babel/webpack-loader.js??ruleSet[1].rules[1].use[0]!./node_modules/@ngtools/webpack/src/ivy/index.js!./node_modules/source-map-loader/dist/cjs.js??ruleSet[1].rules[2]!./node_modules/rxjs/dist/esm/internal/scheduler/AsyncScheduler.jsH  import { Scheduler } from '../Scheduler';
export class AsyncScheduler extends Scheduler {
    constructor(SchedulerAction, now = Scheduler.now) {
        super(SchedulerAction, now);
        this.actions = [];
        this._active = false;
        this._scheduled = undefined;
    }
    flush(action) {
        const { actions } = this;
        if (this._active) {
            actions.push(action);
            return;
        }
        let error;
        this._active = true;
        do {
            if ((error = action.execute(action.state, action.delay))) {
                break;
            }
        } while ((action = actions.shift()));
        this._active = false;
        if (error) {
            while ((action = actions.shift())) {
                action.unsubscribe();
            }
            throw error;
        }
    }
}
 RÿÿÿG  __webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "AsyncScheduler": () => (/* binding */ AsyncScheduler)
/* harmony export */ });
/* harmony import */ var _Scheduler__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../Scheduler */ 2604);
kÿÿÿù¾  webpack://./node_modules/@angular-devkit/build-angular/src/babel/webpack-loader.js??ruleSet[1].rules[1].use[0]!./node_modules/@ngtools/webpack/src/ivy/index.js!./node_modules/source-map-loader/dist/cjs.js??ruleSet[1].rules[2]!./node_modules/rxjs/dist/esm/internal/scheduler/AsyncScheduler.js040undefined4248undefined7886_Scheduler__WEBPACK_IMPORTED_MODULE_0__.Schedulerundefined129141_Scheduler__WEBPACK_IMPORTED_MODULE_0__.Scheduler.nowundefined
VÿÿÿWÿÿÿböÿÿXÿÿÿ.ÿÿÿ/ÿÿÿ   ³  «webpack/lib/util/registerExternalSerializerœwebpack-sources/ConcatSource€«webpack/lib/util/registerExternalSerializer™webpack-sources/RawSource=  __webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "Action": () => (/* binding */ Action)
/* harmony export */ });
/* harmony import */ var _Subscription__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../Subscription */ 1620);
«webpack/lib/util/registerExternalSerializerwebpack-sources/ReplaceSource«webpack/lib/util/registerExternalSerializerwebpack-sources/OriginalSourceÓ   import { Subscription } from '../Subscription';
export class Action extends Subscription {
    constructor(scheduler, work) {
        super();
    }
    schedule(state, delay = 0) {
        return this;
    }
}
  webpack://./node_modules/@angular-devkit/build-angular/src/babel/webpack-loader.js??ruleSet[1].rules[1].use[0]!./node_modules/@ngtools/webpack/src/ivy/index.js!./node_modules/source-map-loader/dist/cjs.js??ruleSet[1].rules[2]!./node_modules/rxjs/dist/esm/internal/scheduler/Action.js d.06LW€€·_Subscription__WEBPACK_IMPORTED_MODULE_0__.Subscription4ÿÿÿ  __webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "Action": () => (/* binding */ Action)
/* harmony export */ });
/* harmony import */ var _Subscription__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../Subscription */ 1620);

class Action extends _Subscription__WEBPACK_IMPORTED_MODULE_0__.Subscription {
    constructor(scheduler, work) {
        super();
    }
    schedule(state, delay = 0) {
        return this;
    }
}
5ÿÿÿ7ÿÿÿ;ÿÿÿxA   ;;;;;AAA+C;AACxC,qBAAqB,uDAAY;AACxC;AACA;AACA;AACA;AACA;AACA;AACA  webpack://./node_modules/@angular-devkit/build-angular/src/babel/webpack-loader.js??ruleSet[1].rules[1].use[0]!./node_modules/@ngtools/webpack/src/ivy/index.js!./node_modules/source-map-loader/dist/cjs.js??ruleSet[1].rules[2]!./node_modules/rxjs/dist/esm/internal/scheduler/Action.jsÓ   import { Subscription } from '../Subscription';
export class Action extends Subscription {
    constructor(scheduler, work) {
        super();
    }
    schedule(state, delay = 0) {
        return this;
    }
}
 @ÿÿÿ=  __webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "Action": () => (/* binding */ Action)
/* harmony export */ });
/* harmony import */ var _Subscription__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../Subscription */ 1620);
Yÿÿÿùx  webpack://./node_modules/@angular-devkit/build-angular/src/babel/webpack-loader.js??ruleSet[1].rules[1].use[0]!./node_modules/@ngtools/webpack/src/ivy/index.js!./node_modules/source-map-loader/dist/cjs.js??ruleSet[1].rules[2]!./node_modules/rxjs/dist/esm/internal/scheduler/Action.js046undefined4854undefined7687_Subscription__WEBPACK_IMPORTED_MODULE_0__.Subscriptionundefined
DÿÿÿEÿÿÿPöÿÿFÿÿÿÿÿÿÿÿÿ     «webpack/lib/util/registerExternalSerializerœwebpack-sources/ConcatSource€«webpack/lib/util/registerExternalSerializer™webpack-sources/RawSourceÙ   __webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "intervalProvider": () => (/* binding */ intervalProvider)
/* harmony export */ });
«webpack/lib/util/registerExternalSerializerwebpack-sources/ReplaceSource«webpack/lib/util/registerExternalSerializerwebpack-sources/OriginalSourceÎ  export const intervalProvider = {
    setInterval(...args) {
        const { delegate } = intervalProvider;
        return ((delegate === null || delegate === void 0 ? void 0 : delegate.setInterval) || setInterval)(...args);
    },
    clearInterval(handle) {
        const { delegate } = intervalProvider;
        return ((delegate === null || delegate === void 0 ? void 0 : delegate.clearInterval) || clearInterval)(handle);
    },
    delegate: undefined,
};
%  webpack://./node_modules/@angular-devkit/build-angular/src/babel/webpack-loader.js??ruleSet[1].rules[1].use[0]!./node_modules/@ngtools/webpack/src/ivy/index.js!./node_modules/source-map-loader/dist/cjs.js??ruleSet[1].rules[2]!./node_modules/rxjs/dist/esm/internal/scheduler/intervalProvider.js €"ÿÿÿ   __webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "intervalProvider": () => (/* binding */ intervalProvider)
/* harmony export */ });
const intervalProvider = {
    setInterval(...args) {
        const { delegate } = intervalProvider;
        return ((delegate === null || delegate === void 0 ? void 0 : delegate.setInterval) || setInterval)(...args);
    },
    clearInterval(handle) {
        const { delegate } = intervalProvider;
        return ((delegate === null || delegate === void 0 ? void 0 : delegate.clearInterval) || clearInterval)(handle);
    },
    delegate: undefined,
};
#ÿÿÿ%ÿÿÿ)ÿÿÿx^   ;;;;AAAO;AACP;AACA,gBAAgB,WAAW;AAC3B;AACA,KAAK;AACL;AACA,gBAAgB,WAAW;AAC3B;AACA,KAAK;AACL;AACA%  webpack://./node_modules/@angular-devkit/build-angular/src/babel/webpack-loader.js??ruleSet[1].rules[1].use[0]!./node_modules/@ngtools/webpack/src/ivy/index.js!./node_modules/source-map-loader/dist/cjs.js??ruleSet[1].rules[2]!./node_modules/rxjs/dist/esm/internal/scheduler/intervalProvider.jsÎ  export const intervalProvider = {
    setInterval(...args) {
        const { delegate } = intervalProvider;
        return ((delegate === null || delegate === void 0 ? void 0 : delegate.setInterval) || setInterval)(...args);
    },
    clearInterval(handle) {
        const { delegate } = intervalProvider;
        return ((delegate === null || delegate === void 0 ? void 0 : delegate.clearInterval) || clearInterval)(handle);
    },
    delegate: undefined,
};
 .ÿÿÿÙ   __webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "intervalProvider": () => (/* binding */ intervalProvider)
/* harmony export */ });
Gÿÿÿù0  webpack://./node_modules/@angular-devkit/build-angular/src/babel/webpack-loader.js??ruleSet[1].rules[1].use[0]!./node_modules/@ngtools/webpack/src/ivy/index.js!./node_modules/source-map-loader/dist/cjs.js??ruleSet[1].rules[2]!./node_modules/rxjs/dist/esm/internal/scheduler/intervalProvider.js06undefined
3ÿÿÿ>öÿÿ4ÿÿÿ
ÿÿÿÿÿÿ   Ìs «webpack/lib/util/registerExternalSerializerœwebpack-sources/ConcatSource€«webpack/lib/util/registerExternalSerializer™webpack-sources/RawSourcev  __webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "A11yModule": () => (/* binding */ A11yModule),
/* harmony export */   "ActiveDescendantKeyManager": () => (/* binding */ ActiveDescendantKeyManager),
/* harmony export */   "AriaDescriber": () => (/* binding */ AriaDescriber),
/* harmony export */   "CDK_DESCRIBEDBY_HOST_ATTRIBUTE": () => (/* binding */ CDK_DESCRIBEDBY_HOST_ATTRIBUTE),
/* harmony export */   "CDK_DESCRIBEDBY_ID_PREFIX": () => (/* binding */ CDK_DESCRIBEDBY_ID_PREFIX),
/* harmony export */   "CdkAriaLive": () => (/* binding */ CdkAriaLive),
/* harmony export */   "CdkMonitorFocus": () => (/* binding */ CdkMonitorFocus),
/* harmony export */   "CdkTrapFocus": () => (/* binding */ CdkTrapFocus),
/* harmony export */   "ConfigurableFocusTrap": () => (/* binding */ ConfigurableFocusTrap),
/* harmony export */   "ConfigurableFocusTrapFactory": () => (/* binding */ ConfigurableFocusTrapFactory),
/* harmony export */   "EventListenerFocusTrapInertStrategy": () => (/* binding */ EventListenerFocusTrapInertStrategy),
/* harmony export */   "FOCUS_MONITOR_DEFAULT_OPTIONS": () => (/* binding */ FOCUS_MONITOR_DEFAULT_OPTIONS),
/* harmony export */   "FOCUS_TRAP_INERT_STRATEGY": () => (/* binding */ FOCUS_TRAP_INERT_STRATEGY),
/* harmony export */   "FocusKeyManager": () => (/* binding */ FocusKeyManager),
/* harmony export */   "FocusMonitor": () => (/* binding */ FocusMonitor),
/* harmony export */   "FocusTrap": () => (/* binding */ FocusTrap),
/* harmony export */   "FocusTrapFactory": () => (/* binding */ FocusTrapFactory),
/* harmony export */   "HighContrastModeDetector": () => (/* binding */ HighContrastModeDetector),
/* harmony export */   "INPUT_MODALITY_DETECTOR_DEFAULT_OPTIONS": () => (/* binding */ INPUT_MODALITY_DETECTOR_DEFAULT_OPTIONS),
/* harmony export */   "INPUT_MODALITY_DETECTOR_OPTIONS": () => (/* binding */ INPUT_MODALITY_DETECTOR_OPTIONS),
/* harmony export */   "InputModalityDetector": () => (/* binding */ InputModalityDetector),
/* harmony export */   "InteractivityChecker": () => (/* binding */ InteractivityChecker),
/* harmony export */   "IsFocusableConfig": () => (/* binding */ IsFocusableConfig),
/* harmony export */   "LIVE_ANNOUNCER_DEFAULT_OPTIONS": () => (/* binding */ LIVE_ANNOUNCER_DEFAULT_OPTIONS),
/* harmony export */   "LIVE_ANNOUNCER_ELEMENT_TOKEN": () => (/* binding */ LIVE_ANNOUNCER_ELEMENT_TOKEN),
/* harmony export */   "LIVE_ANNOUNCER_ELEMENT_TOKEN_FACTORY": () => (/* binding */ LIVE_ANNOUNCER_ELEMENT_TOKEN_FACTORY),
/* harmony export */   "ListKeyManager": () => (/* binding */ ListKeyManager),
/* harmony export */   "LiveAnnouncer": () => (/* binding */ LiveAnnouncer),
/* harmony export */   "MESSAGES_CONTAINER_ID": () => (/* binding */ MESSAGES_CONTAINER_ID),
/* harmony export */   "isFakeMousedownFromScreenReader": () => (/* binding */ isFakeMousedownFromScreenReader),
/* harmony export */   "isFakeTouchstartFromScreenReader": () => (/* binding */ isFakeTouchstartFromScreenReader)
/* harmony export */ });
/* harmony import */ var _angular_common__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! @angular/common */ 8267);
/* harmony import */ var _angular_core__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! @angular/core */ 4001);
/* harmony import */ var rxjs__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! rxjs */ 4575);
/* harmony import */ var rxjs__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! rxjs */ 1620);
/* harmony import */ var rxjs__WEBPACK_IMPORTED_MODULE_12__ = __webpack_require__(/*! rxjs */ 8824);
/* harmony import */ var rxjs__WEBPACK_IMPORTED_MODULE_16__ = __webpack_require__(/*! rxjs */ 8433);
/* harmony import */ var _angular_cdk_keycodes__WEBPACK_IMPORTED_MODULE_8__ = __webpack_require__(/*! @angular/cdk/keycodes */ 7926);
/* harmony import */ var rxjs_operators__WEBPACK_IMPORTED_MODULE_4__ = __webpack_require__(/*! rxjs/operators */ 5309);
/* harmony import */ var rxjs_operators__WEBPACK_IMPORTED_MODULE_5__ = __webpack_require__(/*! rxjs/operators */ 1082);
/* harmony import */ var rxjs_operators__WEBPACK_IMPORTED_MODULE_6__ = __webpack_require__(/*! rxjs/operators */ 1569);
/* harmony import */ var rxjs_operators__WEBPACK_IMPORTED_MODULE_7__ = __webpack_require__(/*! rxjs/operators */ 2014);
/* harmony import */ var rxjs_operators__WEBPACK_IMPORTED_MODULE_10__ = __webpack_require__(/*! rxjs/operators */ 7529);
/* harmony import */ var rxjs_operators__WEBPACK_IMPORTED_MODULE_13__ = __webpack_require__(/*! rxjs/operators */ 3295);
/* harmony import */ var rxjs_operators__WEBPACK_IMPORTED_MODULE_14__ = __webpack_require__(/*! rxjs/operators */ 1607);
/* harmony import */ var rxjs_operators__WEBPACK_IMPORTED_MODULE_17__ = __webpack_require__(/*! rxjs/operators */ 6567);
/* harmony import */ var _angular_cdk_coercion__WEBPACK_IMPORTED_MODULE_11__ = __webpack_require__(/*! @angular/cdk/coercion */ 2270);
/* harmony import */ var _angular_cdk_platform__WEBPACK_IMPORTED_MODULE_9__ = __webpack_require__(/*! @angular/cdk/platform */ 573);
/* harmony import */ var _angular_cdk_observers__WEBPACK_IMPORTED_MODULE_15__ = __webpack_require__(/*! @angular/cdk/observers */ 4095);
«webpack/lib/util/registerExternalSerializerwebpack-sources/ReplaceSource«webpack/lib/util/registerExternalSerializerŸwebpack-sources/SourceMapSourceó„ import { DOCUMENT } from '@angular/common';
import * as i0 from '@angular/core';
import { Injectable, Inject, QueryList, Directive, Input, InjectionToken, Optional, EventEmitter, Output, NgModule } from '@angular/core';
import { Subject, Subscription, BehaviorSubject, of } from 'rxjs';
import { hasModifierKey, A, Z, ZERO, NINE, END, HOME, LEFT_ARROW, RIGHT_ARROW, UP_ARROW, DOWN_ARROW, TAB, ALT, CONTROL, MAC_META, META, SHIFT } from '@angular/cdk/keycodes';
import { tap, debounceTime, filter, map, take, skip, distinctUntilChanged, takeUntil } from 'rxjs/operators';
import { coerceBooleanProperty, coerceElement } from '@angular/cdk/coercion';
import * as i1 from '@angular/cdk/platform';
import { _getFocusedElementPierceShadowDom, normalizePassiveListenerOptions, _getEventTarget, _getShadowRoot, PlatformModule } from '@angular/cdk/platform';
import * as i1$1 from '@angular/cdk/observers';
import { ObserversModule } from '@angular/cdk/observers';
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

/** IDs are delimited by an empty space, as per the spec. */

const ID_DELIMITER = ' ';
/**
 * Adds the given ID to the specified ARIA attribute on an element.
 * Used for attributes such as aria-labelledby, aria-owns, etc.
 */

function addAriaReferencedId(el, attr, id) {
  const ids = getAriaReferenceIds(el, attr);

  if (ids.some(existingId => existingId.trim() == id.trim())) {
    return;
  }

  ids.push(id.trim());
  el.setAttribute(attr, ids.join(ID_DELIMITER));
}
/**
 * Removes the given ID from the specified ARIA attribute on an element.
 * Used for attributes such as aria-labelledby, aria-owns, etc.
 */


function removeAriaReferencedId(el, attr, id) {
  const ids = getAriaReferenceIds(el, attr);
  const filteredIds = ids.filter(val => val != id.trim());

  if (filteredIds.length) {
    el.setAttribute(attr, filteredIds.join(ID_DELIMITER));
  } else {
    el.removeAttribute(attr);
  }
}
/**
 * Gets the list of IDs referenced by the given ARIA attribute on an element.
 * Used for attributes such as aria-labelledby, aria-owns, etc.
 */


function getAriaReferenceIds(el, attr) {
  // Get string array of all individual ids (whitespace delimited) in the attribute value
  return (el.getAttribute(attr) || '').match(/\S+/g) || [];
}
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

/** ID used for the body container where all messages are appended. */


const MESSAGES_CONTAINER_ID = 'cdk-describedby-message-container';
/** ID prefix used for each created message element. */

const CDK_DESCRIBEDBY_ID_PREFIX = 'cdk-describedby-message';
/** Attribute given to each host element that is described by a message element. */

const CDK_DESCRIBEDBY_HOST_ATTRIBUTE = 'cdk-describedby-host';
/** Global incremental identifier for each registered message element. */

let nextId = 0;
/** Global map of all registered message elements that have been placed into the document. */

const messageRegistry = new Map();
/** Container for all registered messages. */

let messagesContainer = null;
/**
 * Utility that creates visually hidden elements with a message content. Useful for elements that
 * want to use aria-describedby to further describe themselves without adding additional visual
 * content.
 */

class AriaDescriber {
  constructor(_document) {
    this._document = _document;
  }

  describe(hostElement, message, role) {
    if (!this._canBeDescribed(hostElement, message)) {
      return;
    }

    const key = getKey(message, role);

    if (typeof message !== 'string') {
      // We need to ensure that the element has an ID.
      setMessageId(message);
      messageRegistry.set(key, {
        messageElement: message,
        referenceCount: 0
      });
    } else if (!messageRegistry.has(key)) {
      this._createMessageElement(message, role);
    }

    if (!this._isElementDescribedByMessage(hostElement, key)) {
      this._addMessageReference(hostElement, key);
    }
  }

  removeDescription(hostElement, message, role) {
    if (!message || !this._isElementNode(hostElement)) {
      return;
    }

    const key = getKey(message, role);

    if (this._isElementDescribedByMessage(hostElement, key)) {
      this._removeMessageReference(hostElement, key);
    } // If the message is a string, it means that it's one that we created for the
    // consumer so we can remove it safely, otherwise we should leave it in place.


    if (typeof message === 'string') {
      const registeredMessage = messageRegistry.get(key);

      if (registeredMessage && registeredMessage.referenceCount === 0) {
        this._deleteMessageElement(key);
      }
    }

    if (messagesContainer && messagesContainer.childNodes.length === 0) {
      this._deleteMessagesContainer();
    }
  }
  /** Unregisters all created message elements and removes the message container. */


  ngOnDestroy() {
    const describedElements = this._document.querySelectorAll(`[${CDK_DESCRIBEDBY_HOST_ATTRIBUTE}]`);

    for (let i = 0; i < describedElements.length; i++) {
      this._removeCdkDescribedByReferenceIds(describedElements[i]);

      describedElements[i].removeAttribute(CDK_DESCRIBEDBY_HOST_ATTRIBUTE);
    }

    if (messagesContainer) {
      this._deleteMessagesContainer();
    }

    messageRegistry.clear();
  }
  /**
   * Creates a new element in the visually hidden message container element with the message
   * as its content and adds it to the message registry.
   */


  _createMessageElement(message, role) {
    const messageElement = this._document.createElement('div');

    setMessageId(messageElement);
    messageElement.textContent = message;

    if (role) {
      messageElement.setAttribute('role', role);
    }

    this._createMessagesContainer();

    messagesContainer.appendChild(messageElement);
    messageRegistry.set(getKey(message, role), {
      messageElement,
      referenceCount: 0
    });
  }
  /** Deletes the message element from the global messages container. */


  _deleteMessageElement(key) {
    const registeredMessage = messageRegistry.get(key);
    registeredMessage?.messageElement?.remove();
    messageRegistry.delete(key);
  }
  /** Creates the global container for all aria-describedby messages. */


  _createMessagesContainer() {
    if (!messagesContainer) {
      const preExistingContainer = this._document.getElementById(MESSAGES_CONTAINER_ID); // When going from the server to the client, we may end up in a situation where there's
      // already a container on the page, but we don't have a reference to it. Clear the
      // old container so we don't get duplicates. Doing this, instead of emptying the previous
      // container, should be slightly faster.


      preExistingContainer?.remove();
      messagesContainer = this._document.createElement('div');
      messagesContainer.id = MESSAGES_CONTAINER_ID; // We add `visibility: hidden` in order to prevent text in this container from
      // being searchable by the browser's Ctrl + F functionality.
      // Screen-readers will still read the description for elements with aria-describedby even
      // when the description element is not visible.

      messagesContainer.style.visibility = 'hidden'; // Even though we use `visibility: hidden`, we still apply `cdk-visually-hidden` so that
      // the description element doesn't impact page layout.

      messagesContainer.classList.add('cdk-visually-hidden');

      this._document.body.appendChild(messagesContainer);
    }
  }
  /** Deletes the global messages container. */


  _deleteMessagesContainer() {
    if (messagesContainer) {
      messagesContainer.remove();
      messagesContainer = null;
    }
  }
  /** Removes all cdk-describedby messages that are hosted through the element. */


  _removeCdkDescribedByReferenceIds(element) {
    // Remove all aria-describedby reference IDs that are prefixed by CDK_DESCRIBEDBY_ID_PREFIX
    const originalReferenceIds = getAriaReferenceIds(element, 'aria-describedby').filter(id => id.indexOf(CDK_DESCRIBEDBY_ID_PREFIX) != 0);
    element.setAttribute('aria-describedby', originalReferenceIds.join(' '));
  }
  /**
   * Adds a message reference to the element using aria-describedby and increments the registered
   * message's reference count.
   */


  _addMessageReference(element, key) {
    const registeredMessage = messageRegistry.get(key); // Add the aria-describedby reference and set the
    // describedby_host attribute to mark the element.

    addAriaReferencedId(element, 'aria-describedby', registeredMessage.messageElement.id);
    element.setAttribute(CDK_DESCRIBEDBY_HOST_ATTRIBUTE, '');
    registeredMessage.referenceCount++;
  }
  /**
   * Removes a message reference from the element using aria-describedby
   * and decrements the registered message's reference count.
   */


  _removeMessageReference(element, key) {
    const registeredMessage = messageRegistry.get(key);
    registeredMessage.referenceCount--;
    removeAriaReferencedId(element, 'aria-describedby', registeredMessage.messageElement.id);
    element.removeAttribute(CDK_DESCRIBEDBY_HOST_ATTRIBUTE);
  }
  /** Returns true if the element has been described by the provided message ID. */


  _isElementDescribedByMessage(element, key) {
    const referenceIds = getAriaReferenceIds(element, 'aria-describedby');
    const registeredMessage = messageRegistry.get(key);
    const messageId = registeredMessage && registeredMessage.messageElement.id;
    return !!messageId && referenceIds.indexOf(messageId) != -1;
  }
  /** Determines whether a message can be described on a particular element. */


  _canBeDescribed(element, message) {
    if (!this._isElementNode(element)) {
      return false;
    }

    if (message && typeof message === 'object') {
      // We'd have to make some assumptions about the description element's text, if the consumer
      // passed in an element. Assume that if an element is passed in, the consumer has verified
      // that it can be used as a description.
      return true;
    }

    const trimmedMessage = message == null ? '' : `${message}`.trim();
    const ariaLabel = element.getAttribute('aria-label'); // We shouldn't set descriptions if they're exactly the same as the `aria-label` of the
    // element, because screen readers will end up reading out the same text twice in a row.

    return trimmedMessage ? !ariaLabel || ariaLabel.trim() !== trimmedMessage : false;
  }
  /** Checks whether a node is an Element node. */


  _isElementNode(element) {
    return element.nodeType === this._document.ELEMENT_NODE;
  }

}

AriaDescriber.Éµfac = function AriaDescriber_Factory(t) {
  return new (t || AriaDescriber)(i0.ÉµÉµinject(DOCUMENT));
};

AriaDescriber.Éµprov = /* @__PURE__ */i0.ÉµÉµdefineInjectable({
  token: AriaDescriber,
  factory: AriaDescriber.Éµfac,
  providedIn: 'root'
});

(function () {
  (typeof ngDevMode === "undefined" || ngDevMode) && i0.ÉµsetClassMetadata(AriaDescriber, [{
    type: Injectable,
    args: [{
      providedIn: 'root'
    }]
  }], function () {
    return [{
      type: undefined,
      decorators: [{
        type: Inject,
        args: [DOCUMENT]
      }]
    }];
  }, null);
})();
/** Gets a key that can be used to look messages up in the registry. */


function getKey(message, role) {
  return typeof message === 'string' ? `${role || ''}/${message}` : message;
}
/** Assigns a unique ID to an element, if it doesn't have one already. */


function setMessageId(element) {
  if (!element.id) {
    element.id = `${CDK_DESCRIBEDBY_ID_PREFIX}-${nextId++}`;
  }
}
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

/**
 * This class manages keyboard events for selectable lists. If you pass it a query list
 * of items, it will set the active item correctly when arrow events occur.
 */


class ListKeyManager {
  constructor(_items) {
    this._items = _items;
    this._activeItemIndex = -1;
    this._activeItem = null;
    this._wrap = false;
    this._letterKeyStream = new Subject();
    this._typeaheadSubscription = Subscription.EMPTY;
    this._vertical = true;
    this._allowedModifierKeys = [];
    this._homeAndEnd = false;
    /**
     * Predicate function that can be used to check whether an item should be skipped
     * by the key manager. By default, disabled items are skipped.
     */

    this._skipPredicateFn = item => item.disabled; // Buffer for the letters that the user has pressed when the typeahead option is turned on.


    this._pressedLetters = [];
    /**
     * Stream that emits any time the TAB key is pressed, so components can react
     * when focus is shifted off of the list.
     */

    this.tabOut = new Subject();
    /** Stream that emits whenever the active item of the list manager changes. */

    this.change = new Subject(); // We allow for the items to be an array because, in some cases, the consumer may
    // not have access to a QueryList of the items they want to manage (e.g. when the
    // items aren't being collected via `ViewChildren` or `ContentChildren`).

    if (_items instanceof QueryList) {
      _items.changes.subscribe(newItems => {
        if (this._activeItem) {
          const itemArray = newItems.toArray();
          const newIndex = itemArray.indexOf(this._activeItem);

          if (newIndex > -1 && newIndex !== this._activeItemIndex) {
            this._activeItemIndex = newIndex;
          }
        }
      });
    }
  }
  /**
   * Sets the predicate function that determines which items should be skipped by the
   * list key manager.
   * @param predicate Function that determines whether the given item should be skipped.
   */


  skipPredicate(predicate) {
    this._skipPredicateFn = predicate;
    return this;
  }
  /**
   * Configures wrapping mode, which determines whether the active item will wrap to
   * the other end of list when there are no more items in the given direction.
   * @param shouldWrap Whether the list should wrap when reaching the end.
   */


  withWrap(shouldWrap = true) {
    this._wrap = shouldWrap;
    return this;
  }
  /**
   * Configures whether the key manager should be able to move the selection vertically.
   * @param enabled Whether vertical selection should be enabled.
   */


  withVerticalOrientation(enabled = true) {
    this._vertical = enabled;
    return this;
  }
  /**
   * Configures the key manager to move the selection horizontally.
   * Passing in `null` will disable horizontal movement.
   * @param direction Direction in which the selection can be moved.
   */


  withHorizontalOrientation(direction) {
    this._horizontal = direction;
    return this;
  }
  /**
   * Modifier keys which are allowed to be held down and whose default actions will be prevented
   * as the user is pressing the arrow keys. Defaults to not allowing any modifier keys.
   */


  withAllowedModifierKeys(keys) {
    this._allowedModifierKeys = keys;
    return this;
  }
  /**
   * Turns on typeahead mode which allows users to set the active item by typing.
   * @param debounceInterval Time to wait after the last keystroke before setting the active item.
   */


  withTypeAhead(debounceInterval = 200) {
    if ((typeof ngDevMode === 'undefined' || ngDevMode) && this._items.length && this._items.some(item => typeof item.getLabel !== 'function')) {
      throw Error('ListKeyManager items in typeahead mode must implement the `getLabel` method.');
    }

    this._typeaheadSubscription.unsubscribe(); // Debounce the presses of non-navigational keys, collect the ones that correspond to letters
    // and convert those letters back into a string. Afterwards find the first item that starts
    // with that string and select it.


    this._typeaheadSubscription = this._letterKeyStream.pipe(tap(letter => this._pressedLetters.push(letter)), debounceTime(debounceInterval), filter(() => this._pressedLetters.length > 0), map(() => this._pressedLetters.join(''))).subscribe(inputString => {
      const items = this._getItemsArray(); // Start at 1 because we want to start searching at the item immediately
      // following the current active item.


      for (let i = 1; i < items.length + 1; i++) {
        const index = (this._activeItemIndex + i) % items.length;
        const item = items[index];

        if (!this._skipPredicateFn(item) && item.getLabel().toUpperCase().trim().indexOf(inputString) === 0) {
          this.setActiveItem(index);
          break;
        }
      }

      this._pressedLetters = [];
    });
    return this;
  }
  /**
   * Configures the key manager to activate the first and last items
   * respectively when the Home or End key is pressed.
   * @param enabled Whether pressing the Home or End key activates the first/last item.
   */


  withHomeAndEnd(enabled = true) {
    this._homeAndEnd = enabled;
    return this;
  }

  setActiveItem(item) {
    const previousActiveItem = this._activeItem;
    this.updateActiveItem(item);

    if (this._activeItem !== previousActiveItem) {
      this.change.next(this._activeItemIndex);
    }
  }
  /**
   * Sets the active item depending on the key event passed in.
   * @param event Keyboard event to be used for determining which element should be active.
   */


  onKeydown(event) {
    const keyCode = event.keyCode;
    const modifiers = ['altKey', 'ctrlKey', 'metaKey', 'shiftKey'];
    const isModifierAllowed = modifiers.every(modifier => {
      return !event[modifier] || this._allowedModifierKeys.indexOf(modifier) > -1;
    });

    switch (keyCode) {
      case TAB:
        this.tabOut.next();
        return;

      case DOWN_ARROW:
        if (this._vertical && isModifierAllowed) {
          this.setNextItemActive();
          break;
        } else {
          return;
        }

      case UP_ARROW:
        if (this._vertical && isModifierAllowed) {
          this.setPreviousItemActive();
          break;
        } else {
          return;
        }

      case RIGHT_ARROW:
        if (this._horizontal && isModifierAllowed) {
          this._horizontal === 'rtl' ? this.setPreviousItemActive() : this.setNextItemActive();
          break;
        } else {
          return;
        }

      case LEFT_ARROW:
        if (this._horizontal && isModifierAllowed) {
          this._horizontal === 'rtl' ? this.setNextItemActive() : this.setPreviousItemActive();
          break;
        } else {
          return;
        }

      case HOME:
        if (this._homeAndEnd && isModifierAllowed) {
          this.setFirstItemActive();
          break;
        } else {
          return;
        }

      case END:
        if (this._homeAndEnd && isModifierAllowed) {
          this.setLastItemActive();
          break;
        } else {
          return;
        }

      default:
        if (isModifierAllowed || hasModifierKey(event, 'shiftKey')) {
          // Attempt to use the `event.key` which also maps it to the user's keyboard language,
          // otherwise fall back to resolving alphanumeric characters via the keyCode.
          if (event.key && event.key.length === 1) {
            this._letterKeyStream.next(event.key.toLocaleUpperCase());
          } else if (keyCode >= A && keyCode <= Z || keyCode >= ZERO && keyCode <= NINE) {
            this._letterKeyStream.next(String.fromCharCode(keyCode));
          }
        } // Note that we return here, in order to avoid preventing
        // the default action of non-navigational keys.


        return;
    }

    this._pressedLetters = [];
    event.preventDefault();
  }
  /** Index of the currently active item. */


  get activeItemIndex() {
    return this._activeItemIndex;
  }
  /** The active item. */


  get activeItem() {
    return this._activeItem;
  }
  /** Gets whether the user is currently typing into the manager using the typeahead feature. */


  isTyping() {
    return this._pressedLetters.length > 0;
  }
  /** Sets the active item to the first enabled item in the list. */


  setFirstItemActive() {
    this._setActiveItemByIndex(0, 1);
  }
  /** Sets the active item to the last enabled item in the list. */


  setLastItemActive() {
    this._setActiveItemByIndex(this._items.length - 1, -1);
  }
  /** Sets the active item to the next enabled item in the list. */


  setNextItemActive() {
    this._activeItemIndex < 0 ? this.setFirstItemActive() : this._setActiveItemByDelta(1);
  }
  /** Sets the active item to a previous enabled item in the list. */


  setPreviousItemActive() {
    this._activeItemIndex < 0 && this._wrap ? this.setLastItemActive() : this._setActiveItemByDelta(-1);
  }

  updateActiveItem(item) {
    const itemArray = this._getItemsArray();

    const index = typeof item === 'number' ? item : itemArray.indexOf(item);
    const activeItem = itemArray[index]; // Explicitly check for `null` and `undefined` because other falsy values are valid.

    this._activeItem = activeItem == null ? null : activeItem;
    this._activeItemIndex = index;
  }
  /**
   * This method sets the active item, given a list of items and the delta between the
   * currently active item and the new active item. It will calculate differently
   * depending on whether wrap mode is turned on.
   */


  _setActiveItemByDelta(delta) {
    this._wrap ? this._setActiveInWrapMode(delta) : this._setActiveInDefaultMode(delta);
  }
  /**
   * Sets the active item properly given "wrap" mode. In other words, it will continue to move
   * down the list until it finds an item that is not disabled, and it will wrap if it
   * encounters either end of the list.
   */


  _setActiveInWrapMode(delta) {
    const items = this._getItemsArray();

    for (let i = 1; i <= items.length; i++) {
      const index = (this._activeItemIndex + delta * i + items.length) % items.length;
      const item = items[index];

      if (!this._skipPredicateFn(item)) {
        this.setActiveItem(index);
        return;
      }
    }
  }
  /**
   * Sets the active item properly given the default mode. In other words, it will
   * continue to move down the list until it finds an item that is not disabled. If
   * it encounters either end of the list, it will stop and not wrap.
   */


  _setActiveInDefaultMode(delta) {
    this._setActiveItemByIndex(this._activeItemIndex + delta, delta);
  }
  /**
   * Sets the active item to the first enabled item starting at the index specified. If the
   * item is disabled, it will move in the fallbackDelta direction until it either
   * finds an enabled item or encounters the end of the list.
   */


  _setActiveItemByIndex(index, fallbackDelta) {
    const items = this._getItemsArray();

    if (!items[index]) {
      return;
    }

    while (this._skipPredicateFn(items[index])) {
      index += fallbackDelta;

      if (!items[index]) {
        return;
      }
    }

    this.setActiveItem(index);
  }
  /** Returns the items as an array. */


  _getItemsArray() {
    return this._items instanceof QueryList ? this._items.toArray() : this._items;
  }

}
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */


class ActiveDescendantKeyManager extends ListKeyManager {
  setActiveItem(index) {
    if (this.activeItem) {
      this.activeItem.setInactiveStyles();
    }

    super.setActiveItem(index);

    if (this.activeItem) {
      this.activeItem.setActiveStyles();
    }
  }

}
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */


class FocusKeyManager extends ListKeyManager {
  constructor() {
    super(...arguments);
    this._origin = 'program';
  }
  /**
   * Sets the focus origin that will be passed in to the items for any subsequent `focus` calls.
   * @param origin Focus origin to be used when focusing items.
   */


  setFocusOrigin(origin) {
    this._origin = origin;
    return this;
  }

  setActiveItem(item) {
    super.setActiveItem(item);

    if (this.activeItem) {
      this.activeItem.focus(this._origin);
    }
  }

}
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

/**
 * Configuration for the isFocusable method.
 */


class IsFocusableConfig {
  constructor() {
    /**
     * Whether to count an element as focusable even if it is not currently visible.
     */
    this.ignoreVisibility = false;
  }

} // The InteractivityChecker leans heavily on the ally.js accessibility utilities.
// Methods like `isTabbable` are only covering specific edge-cases for the browsers which are
// supported.

/**
 * Utility for checking the interactivity of an element, such as whether is is focusable or
 * tabbable.
 */


class InteractivityChecker {
  constructor(_platform) {
    this._platform = _platform;
  }
  /**
   * Gets whether an element is disabled.
   *
   * @param element Element to be checked.
   * @returns Whether the element is disabled.
   */


  isDisabled(element) {
    // This does not capture some cases, such as a non-form control with a disabled attribute or
    // a form control inside of a disabled form, but should capture the most common cases.
    return element.hasAttribute('disabled');
  }
  /**
   * Gets whether an element is visible for the purposes of interactivity.
   *
   * This will capture states like `display: none` and `visibility: hidden`, but not things like
   * being clipped by an `overflow: hidden` parent or being outside the viewport.
   *
   * @returns Whether the element is visible.
   */


  isVisible(element) {
    return hasGeometry(element) && getComputedStyle(element).visibility === 'visible';
  }
  /**
   * Gets whether an element can be reached via Tab key.
   * Assumes that the element has already been checked with isFocusable.
   *
   * @param element Element to be checked.
   * @returns Whether the element is tabbable.
   */


  isTabbable(element) {
    // Nothing is tabbable on the server ğŸ˜
    if (!this._platform.isBrowser) {
      return false;
    }

    const frameElement = getFrameElement(getWindow(element));

    if (frameElement) {
      // Frame elements inherit their tabindex onto all child elements.
      if (getTabIndexValue(frameElement) === -1) {
        return false;
      } // Browsers disable tabbing to an element inside of an invisible frame.


      if (!this.isVisible(frameElement)) {
        return false;
      }
    }

    let nodeName = element.nodeName.toLowerCase();
    let tabIndexValue = getTabIndexValue(element);

    if (element.hasAttribute('contenteditable')) {
      return tabIndexValue !== -1;
    }

    if (nodeName === 'iframe' || nodeName === 'object') {
      // The frame or object's content may be tabbable depending on the content, but it's
      // not possibly to reliably detect the content of the frames. We always consider such
      // elements as non-tabbable.
      return false;
    } // In iOS, the browser only considers some specific elements as tabbable.


    if (this._platform.WEBKIT && this._platform.IOS && !isPotentiallyTabbableIOS(element)) {
      return false;
    }

    if (nodeName === 'audio') {
      // Audio elements without controls enabled are never tabbable, regardless
      // of the tabindex attribute explicitly being set.
      if (!element.hasAttribute('controls')) {
        return false;
      } // Audio elements with controls are by default tabbable unless the
      // tabindex attribute is set to `-1` explicitly.


      return tabIndexValue !== -1;
    }

    if (nodeName === 'video') {
      // For all video elements, if the tabindex attribute is set to `-1`, the video
      // is not tabbable. Note: We cannot rely on the default `HTMLElement.tabIndex`
      // property as that one is set to `-1` in Chrome, Edge and Safari v13.1. The
      // tabindex attribute is the source of truth here.
      if (tabIndexValue === -1) {
        return false;
      } // If the tabindex is explicitly set, and not `-1` (as per check before), the
      // video element is always tabbable (regardless of whether it has controls or not).


      if (tabIndexValue !== null) {
        return true;
      } // Otherwise (when no explicit tabindex is set), a video is only tabbable if it
      // has controls enabled. Firefox is special as videos are always tabbable regardless
      // of whether there are controls or not.


      return this._platform.FIREFOX || element.hasAttribute('controls');
    }

    return element.tabIndex >= 0;
  }
  /**
   * Gets whether an element can be focused by the user.
   *
   * @param element Element to be checked.
   * @param config The config object with options to customize this method's behavior
   * @returns Whether the element is focusable.
   */


  isFocusable(element, config) {
    // Perform checks in order of left to most expensive.
    // Again, naive approach that does not capture many edge cases and browser quirks.
    return isPotentiallyFocusable(element) && !this.isDisabled(element) && (config?.ignoreVisibility || this.isVisible(element));
  }

}

InteractivityChecker.Éµfac = function InteractivityChecker_Factory(t) {
  return new (t || InteractivityChecker)(i0.ÉµÉµinject(i1.Platform));
};

InteractivityChecker.Éµprov = /* @__PURE__ */i0.ÉµÉµdefineInjectable({
  token: InteractivityChecker,
  factory: InteractivityChecker.Éµfac,
  providedIn: 'root'
});

(function () {
  (typeof ngDevMode === "undefined" || ngDevMode) && i0.ÉµsetClassMetadata(InteractivityChecker, [{
    type: Injectable,
    args: [{
      providedIn: 'root'
    }]
  }], function () {
    return [{
      type: i1.Platform
    }];
  }, null);
})();
/**
 * Returns the frame element from a window object. Since browsers like MS Edge throw errors if
 * the frameElement property is being accessed from a different host address, this property
 * should be accessed carefully.
 */


function getFrameElement(window) {
  try {
    return window.frameElement;
  } catch {
    return null;
  }
}
/** Checks whether the specified element has any geometry / rectangles. */


function hasGeometry(element) {
  // Use logic from jQuery to check for an invisible element.
  // See https://github.com/jquery/jquery/blob/master/src/css/hiddenVisibleSelectors.js#L12
  return !!(element.offsetWidth || element.offsetHeight || typeof element.getClientRects === 'function' && element.getClientRects().length);
}
/** Gets whether an element's  */


function isNativeFormElement(element) {
  let nodeName = element.nodeName.toLowerCase();
  return nodeName === 'input' || nodeName === 'select' || nodeName === 'button' || nodeName === 'textarea';
}
/** Gets whether an element is an `<input type="hidden">`. */


function isHiddenInput(element) {
  return isInputElement(element) && element.type == 'hidden';
}
/** Gets whether an element is an anchor that has an href attribute. */


function isAnchorWithHref(element) {
  return isAnchorElement(element) && element.hasAttribute('href');
}
/** Gets whether an element is an input element. */


function isInputElement(element) {
  return element.nodeName.toLowerCase() == 'input';
}
/** Gets whether an element is an anchor element. */


function isAnchorElement(element) {
  return element.nodeName.toLowerCase() == 'a';
}
/** Gets whether an element has a valid tabindex. */


function hasValidTabIndex(element) {
  if (!element.hasAttribute('tabindex') || element.tabIndex === undefined) {
    return false;
  }

  let tabIndex = element.getAttribute('tabindex');
  return !!(tabIndex && !isNaN(parseInt(tabIndex, 10)));
}
/**
 * Returns the parsed tabindex from the element attributes instead of returning the
 * evaluated tabindex from the browsers defaults.
 */


function getTabIndexValue(element) {
  if (!hasValidTabIndex(element)) {
    return null;
  } // See browser issue in Gecko https://bugzilla.mozilla.org/show_bug.cgi?id=1128054


  const tabIndex = parseInt(element.getAttribute('tabindex') || '', 10);
  return isNaN(tabIndex) ? -1 : tabIndex;
}
/** Checks whether the specified element is potentially tabbable on iOS */


function isPotentiallyTabbableIOS(element) {
  let nodeName = element.nodeName.toLowerCase();
  let inputType = nodeName === 'input' && element.type;
  return inputType === 'text' || inputType === 'password' || nodeName === 'select' || nodeName === 'textarea';
}
/**
 * Gets whether an element is potentially focusable without taking current visible/disabled state
 * into account.
 */


function isPotentiallyFocusable(element) {
  // Inputs are potentially focusable *unless* they're type="hidden".
  if (isHiddenInput(element)) {
    return false;
  }

  return isNativeFormElement(element) || isAnchorWithHref(element) || element.hasAttribute('contenteditable') || hasValidTabIndex(element);
}
/** Gets the parent window of a DOM node with regards of being inside of an iframe. */


function getWindow(node) {
  // ownerDocument is null if `node` itself *is* a document.
  return node.ownerDocument && node.ownerDocument.defaultView || window;
}
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

/**
 * Class that allows for trapping focus within a DOM element.
 *
 * This class currently uses a relatively simple approach to focus trapping.
 * It assumes that the tab order is the same as DOM order, which is not necessarily true.
 * Things like `tabIndex > 0`, flex `order`, and shadow roots can cause the two to be misaligned.
 *
 * @deprecated Use `ConfigurableFocusTrap` instead.
 * @breaking-change 11.0.0
 */


class FocusTrap {
  constructor(_element, _checker, _ngZone, _document, deferAnchors = false) {
    this._element = _element;
    this._checker = _checker;
    this._ngZone = _ngZone;
    this._document = _document;
    this._hasAttached = false; // Event listeners for the anchors. Need to be regular functions so that we can unbind them later.

    this.startAnchorListener = () => this.focusLastTabbableElement();

    this.endAnchorListener = () => this.focusFirstTabbableElement();

    this._enabled = true;

    if (!deferAnchors) {
      this.attachAnchors();
    }
  }
  /** Whether the focus trap is active. */


  get enabled() {
    return this._enabled;
  }

  set enabled(value) {
    this._enabled = value;

    if (this._startAnchor && this._endAnchor) {
      this._toggleAnchorTabIndex(value, this._startAnchor);

      this._toggleAnchorTabIndex(value, this._endAnchor);
    }
  }
  /** Destroys the focus trap by cleaning up the anchors. */


  destroy() {
    const startAnchor = this._startAnchor;
    const endAnchor = this._endAnchor;

    if (startAnchor) {
      startAnchor.removeEventListener('focus', this.startAnchorListener);
      startAnchor.remove();
    }

    if (endAnchor) {
      endAnchor.removeEventListener('focus', this.endAnchorListener);
      endAnchor.remove();
    }

    this._startAnchor = this._endAnchor = null;
    this._hasAttached = false;
  }
  /**
   * Inserts the anchors into the DOM. This is usually done automatically
   * in the constructor, but can be deferred for cases like directives with `*ngIf`.
   * @returns Whether the focus trap managed to attach successfully. This may not be the case
   * if the target element isn't currently in the DOM.
   */


  attachAnchors() {
    // If we're not on the browser, there can be no focus to trap.
    if (this._hasAttached) {
      return true;
    }

    this._ngZone.runOutsideAngular(() => {
      if (!this._startAnchor) {
        this._startAnchor = this._createAnchor();

        this._startAnchor.addEventListener('focus', this.startAnchorListener);
      }

      if (!this._endAnchor) {
        this._endAnchor = this._createAnchor();

        this._endAnchor.addEventListener('focus', this.endAnchorListener);
      }
    });

    if (this._element.parentNode) {
      this._element.parentNode.insertBefore(this._startAnchor, this._element);

      this._element.parentNode.insertBefore(this._endAnchor, this._element.nextSibling);

      this._hasAttached = true;
    }

    return this._hasAttached;
  }
  /**
   * Waits for the zone to stabilize, then focuses the first tabbable element.
   * @returns Returns a promise that resolves with a boolean, depending
   * on whether focus was moved successfully.
   */


  focusInitialElementWhenReady(options) {
    return new Promise(resolve => {
      this._executeOnStable(() => resolve(this.focusInitialElement(options)));
    });
  }
  /**
   * Waits for the zone to stabilize, then focuses
   * the first tabbable element within the focus trap region.
   * @returns Returns a promise that resolves with a boolean, depending
   * on whether focus was moved successfully.
   */


  focusFirstTabbableElementWhenReady(options) {
    return new Promise(resolve => {
      this._executeOnStable(() => resolve(this.focusFirstTabbableElement(options)));
    });
  }
  /**
   * Waits for the zone to stabilize, then focuses
   * the last tabbable element within the focus trap region.
   * @returns Returns a promise that resolves with a boolean, depending
   * on whether focus was moved successfully.
   */


  focusLastTabbableElementWhenReady(options) {
    return new Promise(resolve => {
      this._executeOnStable(() => resolve(this.focusLastTabbableElement(options)));
    });
  }
  /**
   * Get the specified boundary element of the trapped region.
   * @param bound The boundary to get (start or end of trapped region).
   * @returns The boundary element.
   */


  _getRegionBoundary(bound) {
    // Contains the deprecated version of selector, for temporary backwards comparability.
    let markers = this._element.querySelectorAll(`[cdk-focus-region-${bound}], ` + `[cdkFocusRegion${bound}], ` + `[cdk-focus-${bound}]`);

    for (let i = 0; i < markers.length; i++) {
      // @breaking-change 8.0.0
      if (markers[i].hasAttribute(`cdk-focus-${bound}`)) {
        console.warn(`Found use of deprecated attribute 'cdk-focus-${bound}', ` + `use 'cdkFocusRegion${bound}' instead. The deprecated ` + `attribute will be removed in 8.0.0.`, markers[i]);
      } else if (markers[i].hasAttribute(`cdk-focus-region-${bound}`)) {
        console.warn(`Found use of deprecated attribute 'cdk-focus-region-${bound}', ` + `use 'cdkFocusRegion${bound}' instead. The deprecated attribute ` + `will be removed in 8.0.0.`, markers[i]);
      }
    }

    if (bound == 'start') {
      return markers.length ? markers[0] : this._getFirstTabbableElement(this._element);
    }

    return markers.length ? markers[markers.length - 1] : this._getLastTabbableElement(this._element);
  }
  /**
   * Focuses the element that should be focused when the focus trap is initialized.
   * @returns Whether focus was moved successfully.
   */


  focusInitialElement(options) {
    // Contains the deprecated version of selector, for temporary backwards comparability.
    const redirectToElement = this._element.querySelector(`[cdk-focus-initial], ` + `[cdkFocusInitial]`);

    if (redirectToElement) {
      // @breaking-change 8.0.0
      if (redirectToElement.hasAttribute(`cdk-focus-initial`)) {
        console.warn(`Found use of deprecated attribute 'cdk-focus-initial', ` + `use 'cdkFocusInitial' instead. The deprecated attribute ` + `will be removed in 8.0.0`, redirectToElement);
      } // Warn the consumer if the element they've pointed to
      // isn't focusable, when not in production mode.


      if ((typeof ngDevMode === 'undefined' || ngDevMode) && !this._checker.isFocusable(redirectToElement)) {
        console.warn(`Element matching '[cdkFocusInitial]' is not focusable.`, redirectToElement);
      }

      if (!this._checker.isFocusable(redirectToElement)) {
        const focusableChild = this._getFirstTabbableElement(redirectToElement);

        focusableChild?.focus(options);
        return !!focusableChild;
      }

      redirectToElement.focus(options);
      return true;
    }

    return this.focusFirstTabbableElement(options);
  }
  /**
   * Focuses the first tabbable element within the focus trap region.
   * @returns Whether focus was moved successfully.
   */


  focusFirstTabbableElement(options) {
    const redirectToElement = this._getRegionBoundary('start');

    if (redirectToElement) {
      redirectToElement.focus(options);
    }

    return !!redirectToElement;
  }
  /**
   * Focuses the last tabbable element within the focus trap region.
   * @returns Whether focus was moved successfully.
   */


  focusLastTabbableElement(options) {
    const redirectToElement = this._getRegionBoundary('end');

    if (redirectToElement) {
      redirectToElement.focus(options);
    }

    return !!redirectToElement;
  }
  /**
   * Checks whether the focus trap has successfully been attached.
   */


  hasAttached() {
    return this._hasAttached;
  }
  /** Get the first tabbable element from a DOM subtree (inclusive). */


  _getFirstTabbableElement(root) {
    if (this._checker.isFocusable(root) && this._checker.isTabbable(root)) {
      return root;
    }

    const children = root.children;

    for (let i = 0; i < children.length; i++) {
      const tabbableChild = children[i].nodeType === this._document.ELEMENT_NODE ? this._getFirstTabbableElement(children[i]) : null;

      if (tabbableChild) {
        return tabbableChild;
      }
    }

    return null;
  }
  /** Get the last tabbable element from a DOM subtree (inclusive). */


  _getLastTabbableElement(root) {
    if (this._checker.isFocusable(root) && this._checker.isTabbable(root)) {
      return root;
    } // Iterate in reverse DOM order.


    const children = root.children;

    for (let i = children.length - 1; i >= 0; i--) {
      const tabbableChild = children[i].nodeType === this._document.ELEMENT_NODE ? this._getLastTabbableElement(children[i]) : null;

      if (tabbableChild) {
        return tabbableChild;
      }
    }

    return null;
  }
  /** Creates an anchor element. */


  _createAnchor() {
    const anchor = this._document.createElement('div');

    this._toggleAnchorTabIndex(this._enabled, anchor);

    anchor.classList.add('cdk-visually-hidden');
    anchor.classList.add('cdk-focus-trap-anchor');
    anchor.setAttribute('aria-hidden', 'true');
    return anchor;
  }
  /**
   * Toggles the `tabindex` of an anchor, based on the enabled state of the focus trap.
   * @param isEnabled Whether the focus trap is enabled.
   * @param anchor Anchor on which to toggle the tabindex.
   */


  _toggleAnchorTabIndex(isEnabled, anchor) {
    // Remove the tabindex completely, rather than setting it to -1, because if the
    // element has a tabindex, the user might still hit it when navigating with the arrow keys.
    isEnabled ? anchor.setAttribute('tabindex', '0') : anchor.removeAttribute('tabindex');
  }
  /**
   * Toggles the`tabindex` of both anchors to either trap Tab focus or allow it to escape.
   * @param enabled: Whether the anchors should trap Tab.
   */


  toggleAnchors(enabled) {
    if (this._startAnchor && this._endAnchor) {
      this._toggleAnchorTabIndex(enabled, this._startAnchor);

      this._toggleAnchorTabIndex(enabled, this._endAnchor);
    }
  }
  /** Executes a function when the zone is stable. */


  _executeOnStable(fn) {
    if (this._ngZone.isStable) {
      fn();
    } else {
      this._ngZone.onStable.pipe(take(1)).subscribe(fn);
    }
  }

}
/**
 * Factory that allows easy instantiation of focus traps.
 * @deprecated Use `ConfigurableFocusTrapFactory` instead.
 * @breaking-change 11.0.0
 */


class FocusTrapFactory {
  constructor(_checker, _ngZone, _document) {
    this._checker = _checker;
    this._ngZone = _ngZone;
    this._document = _document;
  }
  /**
   * Creates a focus-trapped region around the given element.
   * @param element The element around which focus will be trapped.
   * @param deferCaptureElements Defers the creation of focus-capturing elements to be done
   *     manually by the user.
   * @returns The created focus trap instance.
   */


  create(element, deferCaptureElements = false) {
    return new FocusTrap(element, this._checker, this._ngZone, this._document, deferCaptureElements);
  }

}

FocusTrapFactory.Éµfac = function FocusTrapFactory_Factory(t) {
  return new (t || FocusTrapFactory)(i0.ÉµÉµinject(InteractivityChecker), i0.ÉµÉµinject(i0.NgZone), i0.ÉµÉµinject(DOCUMENT));
};

FocusTrapFactory.Éµprov = /* @__PURE__ */i0.ÉµÉµdefineInjectable({
  token: FocusTrapFactory,
  factory: FocusTrapFactory.Éµfac,
  providedIn: 'root'
});

(function () {
  (typeof ngDevMode === "undefined" || ngDevMode) && i0.ÉµsetClassMetadata(FocusTrapFactory, [{
    type: Injectable,
    args: [{
      providedIn: 'root'
    }]
  }], function () {
    return [{
      type: InteractivityChecker
    }, {
      type: i0.NgZone
    }, {
      type: undefined,
      decorators: [{
        type: Inject,
        args: [DOCUMENT]
      }]
    }];
  }, null);
})();
/** Directive for trapping focus within a region. */


class CdkTrapFocus {
  constructor(_elementRef, _focusTrapFactory,
  /**
   * @deprecated No longer being used. To be removed.
   * @breaking-change 13.0.0
   */
  _document) {
    this._elementRef = _elementRef;
    this._focusTrapFactory = _focusTrapFactory;
    /** Previously focused element to restore focus to upon destroy when using autoCapture. */

    this._previouslyFocusedElement = null;
    this.focusTrap = this._focusTrapFactory.create(this._elementRef.nativeElement, true);
  }
  /** Whether the focus trap is active. */


  get enabled() {
    return this.focusTrap.enabled;
  }

  set enabled(value) {
    this.focusTrap.enabled = coerceBooleanProperty(value);
  }
  /**
   * Whether the directive should automatically move focus into the trapped region upon
   * initialization and return focus to the previous activeElement upon destruction.
   */


  get autoCapture() {
    return this._autoCapture;
  }

  set autoCapture(value) {
    this._autoCapture = coerceBooleanProperty(value);
  }

  ngOnDestroy() {
    this.focusTrap.destroy(); // If we stored a previously focused element when using autoCapture, return focus to that
    // element now that the trapped region is being destroyed.

    if (this._previouslyFocusedElement) {
      this._previouslyFocusedElement.focus();

      this._previouslyFocusedElement = null;
    }
  }

  ngAfterContentInit() {
    this.focusTrap.attachAnchors();

    if (this.autoCapture) {
      this._captureFocus();
    }
  }

  ngDoCheck() {
    if (!this.focusTrap.hasAttached()) {
      this.focusTrap.attachAnchors();
    }
  }

  ngOnChanges(changes) {
    const autoCaptureChange = changes['autoCapture'];

    if (autoCaptureChange && !autoCaptureChange.firstChange && this.autoCapture && this.focusTrap.hasAttached()) {
      this._captureFocus();
    }
  }

  _captureFocus() {
    this._previouslyFocusedElement = _getFocusedElementPierceShadowDom();
    this.focusTrap.focusInitialElementWhenReady();
  }

}

CdkTrapFocus.Éµfac = function CdkTrapFocus_Factory(t) {
  return new (t || CdkTrapFocus)(i0.ÉµÉµdirectiveInject(i0.ElementRef), i0.ÉµÉµdirectiveInject(FocusTrapFactory), i0.ÉµÉµdirectiveInject(DOCUMENT));
};

CdkTrapFocus.Éµdir = /* @__PURE__ */i0.ÉµÉµdefineDirective({
  type: CdkTrapFocus,
  selectors: [["", "cdkTrapFocus", ""]],
  inputs: {
    enabled: ["cdkTrapFocus", "enabled"],
    autoCapture: ["cdkTrapFocusAutoCapture", "autoCapture"]
  },
  exportAs: ["cdkTrapFocus"],
  features: [i0.ÉµÉµNgOnChangesFeature]
});

(function () {
  (typeof ngDevMode === "undefined" || ngDevMode) && i0.ÉµsetClassMetadata(CdkTrapFocus, [{
    type: Directive,
    args: [{
      selector: '[cdkTrapFocus]',
      exportAs: 'cdkTrapFocus'
    }]
  }], function () {
    return [{
      type: i0.ElementRef
    }, {
      type: FocusTrapFactory
    }, {
      type: undefined,
      decorators: [{
        type: Inject,
        args: [DOCUMENT]
      }]
    }];
  }, {
    enabled: [{
      type: Input,
      args: ['cdkTrapFocus']
    }],
    autoCapture: [{
      type: Input,
      args: ['cdkTrapFocusAutoCapture']
    }]
  });
})();
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

/**
 * Class that allows for trapping focus within a DOM element.
 *
 * This class uses a strategy pattern that determines how it traps focus.
 * See FocusTrapInertStrategy.
 */


class ConfigurableFocusTrap extends FocusTrap {
  constructor(_element, _checker, _ngZone, _document, _focusTrapManager, _inertStrategy, config) {
    super(_element, _checker, _ngZone, _document, config.defer);
    this._focusTrapManager = _focusTrapManager;
    this._inertStrategy = _inertStrategy;

    this._focusTrapManager.register(this);
  }
  /** Whether the FocusTrap is enabled. */


  get enabled() {
    return this._enabled;
  }

  set enabled(value) {
    this._enabled = value;

    if (this._enabled) {
      this._focusTrapManager.register(this);
    } else {
      this._focusTrapManager.deregister(this);
    }
  }
  /** Notifies the FocusTrapManager that this FocusTrap will be destroyed. */


  destroy() {
    this._focusTrapManager.deregister(this);

    super.destroy();
  }
  /** @docs-private Implemented as part of ManagedFocusTrap. */


  _enable() {
    this._inertStrategy.preventFocus(this);

    this.toggleAnchors(true);
  }
  /** @docs-private Implemented as part of ManagedFocusTrap. */


  _disable() {
    this._inertStrategy.allowFocus(this);

    this.toggleAnchors(false);
  }

}
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

/** The injection token used to specify the inert strategy. */


const FOCUS_TRAP_INERT_STRATEGY = new InjectionToken('FOCUS_TRAP_INERT_STRATEGY');
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

/**
 * Lightweight FocusTrapInertStrategy that adds a document focus event
 * listener to redirect focus back inside the FocusTrap.
 */

class EventListenerFocusTrapInertStrategy {
  constructor() {
    /** Focus event handler. */
    this._listener = null;
  }
  /** Adds a document event listener that keeps focus inside the FocusTrap. */


  preventFocus(focusTrap) {
    // Ensure there's only one listener per document
    if (this._listener) {
      focusTrap._document.removeEventListener('focus', this._listener, true);
    }

    this._listener = e => this._trapFocus(focusTrap, e);

    focusTrap._ngZone.runOutsideAngular(() => {
      focusTrap._document.addEventListener('focus', this._listener, true);
    });
  }
  /** Removes the event listener added in preventFocus. */


  allowFocus(focusTrap) {
    if (!this._listener) {
      return;
    }

    focusTrap._document.removeEventListener('focus', this._listener, true);

    this._listener = null;
  }
  /**
   * Refocuses the first element in the FocusTrap if the focus event target was outside
   * the FocusTrap.
   *
   * This is an event listener callback. The event listener is added in runOutsideAngular,
   * so all this code runs outside Angular as well.
   */


  _trapFocus(focusTrap, event) {
    const target = event.target;
    const focusTrapRoot = focusTrap._element; // Don't refocus if target was in an overlay, because the overlay might be associated
    // with an element inside the FocusTrap, ex. mat-select.

    if (target && !focusTrapRoot.contains(target) && !target.closest?.('div.cdk-overlay-pane')) {
      // Some legacy FocusTrap usages have logic that focuses some element on the page
      // just before FocusTrap is destroyed. For backwards compatibility, wait
      // to be sure FocusTrap is still enabled before refocusing.
      setTimeout(() => {
        // Check whether focus wasn't put back into the focus trap while the timeout was pending.
        if (focusTrap.enabled && !focusTrapRoot.contains(focusTrap._document.activeElement)) {
          focusTrap.focusFirstTabbableElement();
        }
      });
    }
  }

}
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

/** Injectable that ensures only the most recently enabled FocusTrap is active. */


class FocusTrapManager {
  constructor() {
    // A stack of the FocusTraps on the page. Only the FocusTrap at the
    // top of the stack is active.
    this._focusTrapStack = [];
  }
  /**
   * Disables the FocusTrap at the top of the stack, and then pushes
   * the new FocusTrap onto the stack.
   */


  register(focusTrap) {
    // Dedupe focusTraps that register multiple times.
    this._focusTrapStack = this._focusTrapStack.filter(ft => ft !== focusTrap);
    let stack = this._focusTrapStack;

    if (stack.length) {
      stack[stack.length - 1]._disable();
    }

    stack.push(focusTrap);

    focusTrap._enable();
  }
  /**
   * Removes the FocusTrap from the stack, and activates the
   * FocusTrap that is the new top of the stack.
   */


  deregister(focusTrap) {
    focusTrap._disable();

    const stack = this._focusTrapStack;
    const i = stack.indexOf(focusTrap);

    if (i !== -1) {
      stack.splice(i, 1);

      if (stack.length) {
        stack[stack.length - 1]._enable();
      }
    }
  }

}

FocusTrapManager.Éµfac = function FocusTrapManager_Factory(t) {
  return new (t || FocusTrapManager)();
};

FocusTrapManager.Éµprov = /* @__PURE__ */i0.ÉµÉµdefineInjectable({
  token: FocusTrapManager,
  factory: FocusTrapManager.Éµfac,
  providedIn: 'root'
});

(function () {
  (typeof ngDevMode === "undefined" || ngDevMode) && i0.ÉµsetClassMetadata(FocusTrapManager, [{
    type: Injectable,
    args: [{
      providedIn: 'root'
    }]
  }], null, null);
})();
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

/** Factory that allows easy instantiation of configurable focus traps. */


class ConfigurableFocusTrapFactory {
  constructor(_checker, _ngZone, _focusTrapManager, _document, _inertStrategy) {
    this._checker = _checker;
    this._ngZone = _ngZone;
    this._focusTrapManager = _focusTrapManager;
    this._document = _document; // TODO split up the strategies into different modules, similar to DateAdapter.

    this._inertStrategy = _inertStrategy || new EventListenerFocusTrapInertStrategy();
  }

  create(element, config = {
    defer: false
  }) {
    let configObject;

    if (typeof config === 'boolean') {
      configObject = {
        defer: config
      };
    } else {
      configObject = config;
    }

    return new ConfigurableFocusTrap(element, this._checker, this._ngZone, this._document, this._focusTrapManager, this._inertStrategy, configObject);
  }

}

ConfigurableFocusTrapFactory.Éµfac = function ConfigurableFocusTrapFactory_Factory(t) {
  return new (t || ConfigurableFocusTrapFactory)(i0.ÉµÉµinject(InteractivityChecker), i0.ÉµÉµinject(i0.NgZone), i0.ÉµÉµinject(FocusTrapManager), i0.ÉµÉµinject(DOCUMENT), i0.ÉµÉµinject(FOCUS_TRAP_INERT_STRATEGY, 8));
};

ConfigurableFocusTrapFactory.Éµprov = /* @__PURE__ */i0.ÉµÉµdefineInjectable({
  token: ConfigurableFocusTrapFactory,
  factory: ConfigurableFocusTrapFactory.Éµfac,
  providedIn: 'root'
});

(function () {
  (typeof ngDevMode === "undefined" || ngDevMode) && i0.ÉµsetClassMetadata(ConfigurableFocusTrapFactory, [{
    type: Injectable,
    args: [{
      providedIn: 'root'
    }]
  }], function () {
    return [{
      type: InteractivityChecker
    }, {
      type: i0.NgZone
    }, {
      type: FocusTrapManager
    }, {
      type: undefined,
      decorators: [{
        type: Inject,
        args: [DOCUMENT]
      }]
    }, {
      type: undefined,
      decorators: [{
        type: Optional
      }, {
        type: Inject,
        args: [FOCUS_TRAP_INERT_STRATEGY]
      }]
    }];
  }, null);
})();
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

/** Gets whether an event could be a faked `mousedown` event dispatched by a screen reader. */


function isFakeMousedownFromScreenReader(event) {
  // Some screen readers will dispatch a fake `mousedown` event when pressing enter or space on
  // a clickable element. We can distinguish these events when both `offsetX` and `offsetY` are
  // zero. Note that there's an edge case where the user could click the 0x0 spot of the screen
  // themselves, but that is unlikely to contain interaction elements. Historically we used to
  // check `event.buttons === 0`, however that no longer works on recent versions of NVDA.
  return event.offsetX === 0 && event.offsetY === 0;
}
/** Gets whether an event could be a faked `touchstart` event dispatched by a screen reader. */


function isFakeTouchstartFromScreenReader(event) {
  const touch = event.touches && event.touches[0] || event.changedTouches && event.changedTouches[0]; // A fake `touchstart` can be distinguished from a real one by looking at the `identifier`
  // which is typically >= 0 on a real device versus -1 from a screen reader. Just to be safe,
  // we can also look at `radiusX` and `radiusY`. This behavior was observed against a Windows 10
  // device with a touch screen running NVDA v2020.4 and Firefox 85 or Chrome 88.

  return !!touch && touch.identifier === -1 && (touch.radiusX == null || touch.radiusX === 1) && (touch.radiusY == null || touch.radiusY === 1);
}
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

/**
 * Injectable options for the InputModalityDetector. These are shallowly merged with the default
 * options.
 */


const INPUT_MODALITY_DETECTOR_OPTIONS = new InjectionToken('cdk-input-modality-detector-options');
/**
 * Default options for the InputModalityDetector.
 *
 * Modifier keys are ignored by default (i.e. when pressed won't cause the service to detect
 * keyboard input modality) for two reasons:
 *
 * 1. Modifier keys are commonly used with mouse to perform actions such as 'right click' or 'open
 *    in new tab', and are thus less representative of actual keyboard interaction.
 * 2. VoiceOver triggers some keyboard events when linearly navigating with Control + Option (but
 *    confusingly not with Caps Lock). Thus, to have parity with other screen readers, we ignore
 *    these keys so as to not update the input modality.
 *
 * Note that we do not by default ignore the right Meta key on Safari because it has the same key
 * code as the ContextMenu key on other browsers. When we switch to using event.key, we can
 * distinguish between the two.
 */

const INPUT_MODALITY_DETECTOR_DEFAULT_OPTIONS = {
  ignoreKeys: [ALT, CONTROL, MAC_META, META, SHIFT]
};
/**
 * The amount of time needed to pass after a touchstart event in order for a subsequent mousedown
 * event to be attributed as mouse and not touch.
 *
 * This is the value used by AngularJS Material. Through trial and error (on iPhone 6S) they found
 * that a value of around 650ms seems appropriate.
 */

const TOUCH_BUFFER_MS = 650;
/**
 * Event listener options that enable capturing and also mark the listener as passive if the browser
 * supports it.
 */

const modalityEventListenerOptions = normalizePassiveListenerOptions({
  passive: true,
  capture: true
});
/**
 * Service that detects the user's input modality.
 *
 * This service does not update the input modality when a user navigates with a screen reader
 * (e.g. linear navigation with VoiceOver, object navigation / browse mode with NVDA, virtual PC
 * cursor mode with JAWS). This is in part due to technical limitations (i.e. keyboard events do not
 * fire as expected in these modes) but is also arguably the correct behavior. Navigating with a
 * screen reader is akin to visually scanning a page, and should not be interpreted as actual user
 * input interaction.
 *
 * When a user is not navigating but *interacting* with a screen reader, this service attempts to
 * update the input modality to keyboard, but in general this service's behavior is largely
 * undefined.
 */

class InputModalityDetector {
  constructor(_platform, ngZone, document, options) {
    this._platform = _platform;
    /**
     * The most recently detected input modality event target. Is null if no input modality has been
     * detected or if the associated event target is null for some unknown reason.
     */

    this._mostRecentTarget = null;
    /** The underlying BehaviorSubject that emits whenever an input modality is detected. */

    this._modality = new BehaviorSubject(null);
    /**
     * The timestamp of the last touch input modality. Used to determine whether mousedown events
     * should be attributed to mouse or touch.
     */

    this._lastTouchMs = 0;
    /**
     * Handles keydown events. Must be an arrow function in order to preserve the context when it gets
     * bound.
     */

    this._onKeydown = event => {
      // If this is one of the keys we should ignore, then ignore it and don't update the input
      // modality to keyboard.
      if (this._options?.ignoreKeys?.some(keyCode => keyCode === event.keyCode)) {
        return;
      }

      this._modality.next('keyboard');

      this._mostRecentTarget = _getEventTarget(event);
    };
    /**
     * Handles mousedown events. Must be an arrow function in order to preserve the context when it
     * gets bound.
     */


    this._onMousedown = event => {
      // Touches trigger both touch and mouse events, so we need to distinguish between mouse events
      // that were triggered via mouse vs touch. To do so, check if the mouse event occurs closely
      // after the previous touch event.
      if (Date.now() - this._lastTouchMs < TOUCH_BUFFER_MS) {
        return;
      } // Fake mousedown events are fired by some screen readers when controls are activated by the
      // screen reader. Attribute them to keyboard input modality.


      this._modality.next(isFakeMousedownFromScreenReader(event) ? 'keyboard' : 'mouse');

      this._mostRecentTarget = _getEventTarget(event);
    };
    /**
     * Handles touchstart events. Must be an arrow function in order to preserve the context when it
     * gets bound.
     */


    this._onTouchstart = event => {
      // Same scenario as mentioned in _onMousedown, but on touch screen devices, fake touchstart
      // events are fired. Again, attribute to keyboard input modality.
      if (isFakeTouchstartFromScreenReader(event)) {
        this._modality.next('keyboard');

        return;
      } // Store the timestamp of this touch event, as it's used to distinguish between mouse events
      // triggered via mouse vs touch.


      this._lastTouchMs = Date.now();

      this._modality.next('touch');

      this._mostRecentTarget = _getEventTarget(event);
    };

    this._options = { ...INPUT_MODALITY_DETECTOR_DEFAULT_OPTIONS,
      ...options
    }; // Skip the first emission as it's null.

    this.modalityDetected = this._modality.pipe(skip(1));
    this.modalityChanged = this.modalityDetected.pipe(distinctUntilChanged()); // If we're not in a browser, this service should do nothing, as there's no relevant input
    // modality to detect.

    if (_platform.isBrowser) {
      ngZone.runOutsideAngular(() => {
        document.addEventListener('keydown', this._onKeydown, modalityEventListenerOptions);
        document.addEventListener('mousedown', this._onMousedown, modalityEventListenerOptions);
        document.addEventListener('touchstart', this._onTouchstart, modalityEventListenerOptions);
      });
    }
  }
  /** The most recently detected input modality. */


  get mostRecentModality() {
    return this._modality.value;
  }

  ngOnDestroy() {
    this._modality.complete();

    if (this._platform.isBrowser) {
      document.removeEventListener('keydown', this._onKeydown, modalityEventListenerOptions);
      document.removeEventListener('mousedown', this._onMousedown, modalityEventListenerOptions);
      document.removeEventListener('touchstart', this._onTouchstart, modalityEventListenerOptions);
    }
  }

}

InputModalityDetector.Éµfac = function InputModalityDetector_Factory(t) {
  return new (t || InputModalityDetector)(i0.ÉµÉµinject(i1.Platform), i0.ÉµÉµinject(i0.NgZone), i0.ÉµÉµinject(DOCUMENT), i0.ÉµÉµinject(INPUT_MODALITY_DETECTOR_OPTIONS, 8));
};

InputModalityDetector.Éµprov = /* @__PURE__ */i0.ÉµÉµdefineInjectable({
  token: InputModalityDetector,
  factory: InputModalityDetector.Éµfac,
  providedIn: 'root'
});

(function () {
  (typeof ngDevMode === "undefined" || ngDevMode) && i0.ÉµsetClassMetadata(InputModalityDetector, [{
    type: Injectable,
    args: [{
      providedIn: 'root'
    }]
  }], function () {
    return [{
      type: i1.Platform
    }, {
      type: i0.NgZone
    }, {
      type: Document,
      decorators: [{
        type: Inject,
        args: [DOCUMENT]
      }]
    }, {
      type: undefined,
      decorators: [{
        type: Optional
      }, {
        type: Inject,
        args: [INPUT_MODALITY_DETECTOR_OPTIONS]
      }]
    }];
  }, null);
})();
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */


const LIVE_ANNOUNCER_ELEMENT_TOKEN = new InjectionToken('liveAnnouncerElement', {
  providedIn: 'root',
  factory: LIVE_ANNOUNCER_ELEMENT_TOKEN_FACTORY
});
/** @docs-private */

function LIVE_ANNOUNCER_ELEMENT_TOKEN_FACTORY() {
  return null;
}
/** Injection token that can be used to configure the default options for the LiveAnnouncer. */


const LIVE_ANNOUNCER_DEFAULT_OPTIONS = new InjectionToken('LIVE_ANNOUNCER_DEFAULT_OPTIONS');
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

class LiveAnnouncer {
  constructor(elementToken, _ngZone, _document, _defaultOptions) {
    this._ngZone = _ngZone;
    this._defaultOptions = _defaultOptions; // We inject the live element and document as `any` because the constructor signature cannot
    // reference browser globals (HTMLElement, Document) on non-browser environments, since having
    // a class decorator causes TypeScript to preserve the constructor signature types.

    this._document = _document;
    this._liveElement = elementToken || this._createLiveElement();
  }

  announce(message, ...args) {
    const defaultOptions = this._defaultOptions;
    let politeness;
    let duration;

    if (args.length === 1 && typeof args[0] === 'number') {
      duration = args[0];
    } else {
      [politeness, duration] = args;
    }

    this.clear();
    clearTimeout(this._previousTimeout);

    if (!politeness) {
      politeness = defaultOptions && defaultOptions.politeness ? defaultOptions.politeness : 'polite';
    }

    if (duration == null && defaultOptions) {
      duration = defaultOptions.duration;
    } // TODO: ensure changing the politeness works on all environments we support.


    this._liveElement.setAttribute('aria-live', politeness); // This 100ms timeout is necessary for some browser + screen-reader combinations:
    // - Both JAWS and NVDA over IE11 will not announce anything without a non-zero timeout.
    // - With Chrome and IE11 with NVDA or JAWS, a repeated (identical) message won't be read a
    //   second time without clearing and then using a non-zero delay.
    // (using JAWS 17 at time of this writing).


    return this._ngZone.runOutsideAngular(() => {
      return new Promise(resolve => {
        clearTimeout(this._previousTimeout);
        this._previousTimeout = setTimeout(() => {
          this._liveElement.textContent = message;
          resolve();

          if (typeof duration === 'number') {
            this._previousTimeout = setTimeout(() => this.clear(), duration);
          }
        }, 100);
      });
    });
  }
  /**
   * Clears the current text from the announcer element. Can be used to prevent
   * screen readers from reading the text out again while the user is going
   * through the page landmarks.
   */


  clear() {
    if (this._liveElement) {
      this._liveElement.textContent = '';
    }
  }

  ngOnDestroy() {
    clearTimeout(this._previousTimeout);
    this._liveElement?.remove();
    this._liveElement = null;
  }

  _createLiveElement() {
    const elementClass = 'cdk-live-announcer-element';

    const previousElements = this._document.getElementsByClassName(elementClass);

    const liveEl = this._document.createElement('div'); // Remove any old containers. This can happen when coming in from a server-side-rendered page.


    for (let i = 0; i < previousElements.length; i++) {
      previousElements[i].remove();
    }

    liveEl.classList.add(elementClass);
    liveEl.classList.add('cdk-visually-hidden');
    liveEl.setAttribute('aria-atomic', 'true');
    liveEl.setAttribute('aria-live', 'polite');

    this._document.body.appendChild(liveEl);

    return liveEl;
  }

}

LiveAnnouncer.Éµfac = function LiveAnnouncer_Factory(t) {
  return new (t || LiveAnnouncer)(i0.ÉµÉµinject(LIVE_ANNOUNCER_ELEMENT_TOKEN, 8), i0.ÉµÉµinject(i0.NgZone), i0.ÉµÉµinject(DOCUMENT), i0.ÉµÉµinject(LIVE_ANNOUNCER_DEFAULT_OPTIONS, 8));
};

LiveAnnouncer.Éµprov = /* @__PURE__ */i0.ÉµÉµdefineInjectable({
  token: LiveAnnouncer,
  factory: LiveAnnouncer.Éµfac,
  providedIn: 'root'
});

(function () {
  (typeof ngDevMode === "undefined" || ngDevMode) && i0.ÉµsetClassMetadata(LiveAnnouncer, [{
    type: Injectable,
    args: [{
      providedIn: 'root'
    }]
  }], function () {
    return [{
      type: undefined,
      decorators: [{
        type: Optional
      }, {
        type: Inject,
        args: [LIVE_ANNOUNCER_ELEMENT_TOKEN]
      }]
    }, {
      type: i0.NgZone
    }, {
      type: undefined,
      decorators: [{
        type: Inject,
        args: [DOCUMENT]
      }]
    }, {
      type: undefined,
      decorators: [{
        type: Optional
      }, {
        type: Inject,
        args: [LIVE_ANNOUNCER_DEFAULT_OPTIONS]
      }]
    }];
  }, null);
})();
/**
 * A directive that works similarly to aria-live, but uses the LiveAnnouncer to ensure compatibility
 * with a wider range of browsers and screen readers.
 */


class CdkAriaLive {
  constructor(_elementRef, _liveAnnouncer, _contentObserver, _ngZone) {
    this._elementRef = _elementRef;
    this._liveAnnouncer = _liveAnnouncer;
    this._contentObserver = _contentObserver;
    this._ngZone = _ngZone;
    this._politeness = 'polite';
  }
  /** The aria-live politeness level to use when announcing messages. */


  get politeness() {
    return this._politeness;
  }

  set politeness(value) {
    this._politeness = value === 'off' || value === 'assertive' ? value : 'polite';

    if (this._politeness === 'off') {
      if (this._subscription) {
        this._subscription.unsubscribe();

        this._subscription = null;
      }
    } else if (!this._subscription) {
      this._subscription = this._ngZone.runOutsideAngular(() => {
        return this._contentObserver.observe(this._elementRef).subscribe(() => {
          // Note that we use textContent here, rather than innerText, in order to avoid a reflow.
          const elementText = this._elementRef.nativeElement.textContent; // The `MutationObserver` fires also for attribute
          // changes which we don't want to announce.

          if (elementText !== this._previousAnnouncedText) {
            this._liveAnnouncer.announce(elementText, this._politeness);

            this._previousAnnouncedText = elementText;
          }
        });
      });
    }
  }

  ngOnDestroy() {
    if (this._subscription) {
      this._subscription.unsubscribe();
    }
  }

}

CdkAriaLive.Éµfac = function CdkAriaLive_Factory(t) {
  return new (t || CdkAriaLive)(i0.ÉµÉµdirectiveInject(i0.ElementRef), i0.ÉµÉµdirectiveInject(LiveAnnouncer), i0.ÉµÉµdirectiveInject(i1$1.ContentObserver), i0.ÉµÉµdirectiveInject(i0.NgZone));
};

CdkAriaLive.Éµdir = /* @__PURE__ */i0.ÉµÉµdefineDirective({
  type: CdkAriaLive,
  selectors: [["", "cdkAriaLive", ""]],
  inputs: {
    politeness: ["cdkAriaLive", "politeness"]
  },
  exportAs: ["cdkAriaLive"]
});

(function () {
  (typeof ngDevMode === "undefined" || ngDevMode) && i0.ÉµsetClassMetadata(CdkAriaLive, [{
    type: Directive,
    args: [{
      selector: '[cdkAriaLive]',
      exportAs: 'cdkAriaLive'
    }]
  }], function () {
    return [{
      type: i0.ElementRef
    }, {
      type: LiveAnnouncer
    }, {
      type: i1$1.ContentObserver
    }, {
      type: i0.NgZone
    }];
  }, {
    politeness: [{
      type: Input,
      args: ['cdkAriaLive']
    }]
  });
})();
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

/** InjectionToken for FocusMonitorOptions. */


const FOCUS_MONITOR_DEFAULT_OPTIONS = new InjectionToken('cdk-focus-monitor-default-options');
/**
 * Event listener options that enable capturing and also
 * mark the listener as passive if the browser supports it.
 */

const captureEventListenerOptions = normalizePassiveListenerOptions({
  passive: true,
  capture: true
});
/** Monitors mouse and keyboard events to determine the cause of focus events. */

class FocusMonitor {
  constructor(_ngZone, _platform, _inputModalityDetector,
  /** @breaking-change 11.0.0 make document required */
  document, options) {
    this._ngZone = _ngZone;
    this._platform = _platform;
    this._inputModalityDetector = _inputModalityDetector;
    /** The focus origin that the next focus event is a result of. */

    this._origin = null;
    /** Whether the window has just been focused. */

    this._windowFocused = false;
    /**
     * Whether the origin was determined via a touch interaction. Necessary as properly attributing
     * focus events to touch interactions requires special logic.
     */

    this._originFromTouchInteraction = false;
    /** Map of elements being monitored to their info. */

    this._elementInfo = new Map();
    /** The number of elements currently being monitored. */

    this._monitoredElementCount = 0;
    /**
     * Keeps track of the root nodes to which we've currently bound a focus/blur handler,
     * as well as the number of monitored elements that they contain. We have to treat focus/blur
     * handlers differently from the rest of the events, because the browser won't emit events
     * to the document when focus moves inside of a shadow root.
     */

    this._rootNodeFocusListenerCount = new Map();
    /**
     * Event listener for `focus` events on the window.
     * Needs to be an arrow function in order to preserve the context when it gets bound.
     */

    this._windowFocusListener = () => {
      // Make a note of when the window regains focus, so we can
      // restore the origin info for the focused element.
      this._windowFocused = true;
      this._windowFocusTimeoutId = setTimeout(() => this._windowFocused = false);
    };
    /** Subject for stopping our InputModalityDetector subscription. */


    this._stopInputModalityDetector = new Subject();
    /**
     * Event listener for `focus` and 'blur' events on the document.
     * Needs to be an arrow function in order to preserve the context when it gets bound.
     */

    this._rootNodeFocusAndBlurListener = event => {
      const target = _getEventTarget(event);

      const handler = event.type === 'focus' ? this._onFocus : this._onBlur; // We need to walk up the ancestor chain in order to support `checkChildren`.

      for (let element = target; element; element = element.parentElement) {
        handler.call(this, event, element);
      }
    };

    this._document = document;
    this._detectionMode = options?.detectionMode || 0
    /* IMMEDIATE */
    ;
  }

  monitor(element, checkChildren = false) {
    const nativeElement = coerceElement(element); // Do nothing if we're not on the browser platform or the passed in node isn't an element.

    if (!this._platform.isBrowser || nativeElement.nodeType !== 1) {
      return of(null);
    } // If the element is inside the shadow DOM, we need to bind our focus/blur listeners to
    // the shadow root, rather than the `document`, because the browser won't emit focus events
    // to the `document`, if focus is moving within the same shadow root.


    const rootNode = _getShadowRoot(nativeElement) || this._getDocument();

    const cachedInfo = this._elementInfo.get(nativeElement); // Check if we're already monitoring this element.


    if (cachedInfo) {
      if (checkChildren) {
        // TODO(COMP-318): this can be problematic, because it'll turn all non-checkChildren
        // observers into ones that behave as if `checkChildren` was turned on. We need a more
        // robust solution.
        cachedInfo.checkChildren = true;
      }

      return cachedInfo.subject;
    } // Create monitored element info.


    const info = {
      checkChildren: checkChildren,
      subject: new Subject(),
      rootNode
    };

    this._elementInfo.set(nativeElement, info);

    this._registerGlobalListeners(info);

    return info.subject;
  }

  stopMonitoring(element) {
    const nativeElement = coerceElement(element);

    const elementInfo = this._elementInfo.get(nativeElement);

    if (elementInfo) {
      elementInfo.subject.complete();

      this._setClasses(nativeElement);

      this._elementInfo.delete(nativeElement);

      this._removeGlobalListeners(elementInfo);
    }
  }

  focusVia(element, origin, options) {
    const nativeElement = coerceElement(element);

    const focusedElement = this._getDocument().activeElement; // If the element is focused already, calling `focus` again won't trigger the event listener
    // which means that the focus classes won't be updated. If that's the case, update the classes
    // directly without waiting for an event.


    if (nativeElement === focusedElement) {
      this._getClosestElementsInfo(nativeElement).forEach(([currentElement, info]) => this._originChanged(currentElement, origin, info));
    } else {
      this._setOrigin(origin); // `focus` isn't available on the server


      if (typeof nativeElement.focus === 'function') {
        nativeElement.focus(options);
      }
    }
  }

  ngOnDestroy() {
    this._elementInfo.forEach((_info, element) => this.stopMonitoring(element));
  }
  /** Access injected document if available or fallback to global document reference */


  _getDocument() {
    return this._document || document;
  }
  /** Use defaultView of injected document if available or fallback to global window reference */


  _getWindow() {
    const doc = this._getDocument();

    return doc.defaultView || window;
  }

  _getFocusOrigin(focusEventTarget) {
    if (this._origin) {
      // If the origin was realized via a touch interaction, we need to perform additional checks
      // to determine whether the focus origin should be attributed to touch or program.
      if (this._originFromTouchInteraction) {
        return this._shouldBeAttributedToTouch(focusEventTarget) ? 'touch' : 'program';
      } else {
        return this._origin;
      }
    } // If the window has just regained focus, we can restore the most recent origin from before the
    // window blurred. Otherwise, we've reached the point where we can't identify the source of the
    // focus. This typically means one of two things happened:
    //
    // 1) The element was programmatically focused, or
    // 2) The element was focused via screen reader navigation (which generally doesn't fire
    //    events).
    //
    // Because we can't distinguish between these two cases, we default to setting `program`.


    return this._windowFocused && this._lastFocusOrigin ? this._lastFocusOrigin : 'program';
  }
  /**
   * Returns whether the focus event should be attributed to touch. Recall that in IMMEDIATE mode, a
   * touch origin isn't immediately reset at the next tick (see _setOrigin). This means that when we
   * handle a focus event following a touch interaction, we need to determine whether (1) the focus
   * event was directly caused by the touch interaction or (2) the focus event was caused by a
   * subsequent programmatic focus call triggered by the touch interaction.
   * @param focusEventTarget The target of the focus event under examination.
   */


  _shouldBeAttributedToTouch(focusEventTarget) {
    // Please note that this check is not perfect. Consider the following edge case:
    //
    // <div #parent tabindex="0">
    //   <div #child tabindex="0" (click)="#parent.focus()"></div>
    // </div>
    //
    // Suppose there is a FocusMonitor in IMMEDIATE mode attached to #parent. When the user touches
    // #child, #parent is programmatically focused. This code will attribute the focus to touch
    // instead of program. This is a relatively minor edge-case that can be worked around by using
    // focusVia(parent, 'program') to focus #parent.
    return this._detectionMode === 1
    /* EVENTUAL */
    || !!focusEventTarget?.contains(this._inputModalityDetector._mostRecentTarget);
  }
  /**
   * Sets the focus classes on the element based on the given focus origin.
   * @param element The element to update the classes on.
   * @param origin The focus origin.
   */


  _setClasses(element, origin) {
    element.classList.toggle('cdk-focused', !!origin);
    element.classList.toggle('cdk-touch-focused', origin === 'touch');
    element.classList.toggle('cdk-keyboard-focused', origin === 'keyboard');
    element.classList.toggle('cdk-mouse-focused', origin === 'mouse');
    element.classList.toggle('cdk-program-focused', origin === 'program');
  }
  /**
   * Updates the focus origin. If we're using immediate detection mode, we schedule an async
   * function to clear the origin at the end of a timeout. The duration of the timeout depends on
   * the origin being set.
   * @param origin The origin to set.
   * @param isFromInteraction Whether we are setting the origin from an interaction event.
   */


  _setOrigin(origin, isFromInteraction = false) {
    this._ngZone.runOutsideAngular(() => {
      this._origin = origin;
      this._originFromTouchInteraction = origin === 'touch' && isFromInteraction; // If we're in IMMEDIATE mode, reset the origin at the next tick (or in `TOUCH_BUFFER_MS` ms
      // for a touch event). We reset the origin at the next tick because Firefox focuses one tick
      // after the interaction event. We wait `TOUCH_BUFFER_MS` ms before resetting the origin for
      // a touch event because when a touch event is fired, the associated focus event isn't yet in
      // the event queue. Before doing so, clear any pending timeouts.

      if (this._detectionMode === 0
      /* IMMEDIATE */
      ) {
        clearTimeout(this._originTimeoutId);
        const ms = this._originFromTouchInteraction ? TOUCH_BUFFER_MS : 1;
        this._originTimeoutId = setTimeout(() => this._origin = null, ms);
      }
    });
  }
  /**
   * Handles focus events on a registered element.
   * @param event The focus event.
   * @param element The monitored element.
   */


  _onFocus(event, element) {
    // NOTE(mmalerba): We currently set the classes based on the focus origin of the most recent
    // focus event affecting the monitored element. If we want to use the origin of the first event
    // instead we should check for the cdk-focused class here and return if the element already has
    // it. (This only matters for elements that have includesChildren = true).
    // If we are not counting child-element-focus as focused, make sure that the event target is the
    // monitored element itself.
    const elementInfo = this._elementInfo.get(element);

    const focusEventTarget = _getEventTarget(event);

    if (!elementInfo || !elementInfo.checkChildren && element !== focusEventTarget) {
      return;
    }

    this._originChanged(element, this._getFocusOrigin(focusEventTarget), elementInfo);
  }
  /**
   * Handles blur events on a registered element.
   * @param event The blur event.
   * @param element The monitored element.
   */


  _onBlur(event, element) {
    // If we are counting child-element-focus as focused, make sure that we aren't just blurring in
    // order to focus another child of the monitored element.
    const elementInfo = this._elementInfo.get(element);

    if (!elementInfo || elementInfo.checkChildren && event.relatedTarget instanceof Node && element.contains(event.relatedTarget)) {
      return;
    }

    this._setClasses(element);

    this._emitOrigin(elementInfo.subject, null);
  }

  _emitOrigin(subject, origin) {
    this._ngZone.run(() => subject.next(origin));
  }

  _registerGlobalListeners(elementInfo) {
    if (!this._platform.isBrowser) {
      return;
    }

    const rootNode = elementInfo.rootNode;
    const rootNodeFocusListeners = this._rootNodeFocusListenerCount.get(rootNode) || 0;

    if (!rootNodeFocusListeners) {
      this._ngZone.runOutsideAngular(() => {
        rootNode.addEventListener('focus', this._rootNodeFocusAndBlurListener, captureEventListenerOptions);
        rootNode.addEventListener('blur', this._rootNodeFocusAndBlurListener, captureEventListenerOptions);
      });
    }

    this._rootNodeFocusListenerCount.set(rootNode, rootNodeFocusListeners + 1); // Register global listeners when first element is monitored.


    if (++this._monitoredElementCount === 1) {
      // Note: we listen to events in the capture phase so we
      // can detect them even if the user stops propagation.
      this._ngZone.runOutsideAngular(() => {
        const window = this._getWindow();

        window.addEventListener('focus', this._windowFocusListener);
      }); // The InputModalityDetector is also just a collection of global listeners.


      this._inputModalityDetector.modalityDetected.pipe(takeUntil(this._stopInputModalityDetector)).subscribe(modality => {
        this._setOrigin(modality, true
        /* isFromInteraction */
        );
      });
    }
  }

  _removeGlobalListeners(elementInfo) {
    const rootNode = elementInfo.rootNode;

    if (this._rootNodeFocusListenerCount.has(rootNode)) {
      const rootNodeFocusListeners = this._rootNodeFocusListenerCount.get(rootNode);

      if (rootNodeFocusListeners > 1) {
        this._rootNodeFocusListenerCount.set(rootNode, rootNodeFocusListeners - 1);
      } else {
        rootNode.removeEventListener('focus', this._rootNodeFocusAndBlurListener, captureEventListenerOptions);
        rootNode.removeEventListener('blur', this._rootNodeFocusAndBlurListener, captureEventListenerOptions);

        this._rootNodeFocusListenerCount.delete(rootNode);
      }
    } // Unregister global listeners when last element is unmonitored.


    if (! --this._monitoredElementCount) {
      const window = this._getWindow();

      window.removeEventListener('focus', this._windowFocusListener); // Equivalently, stop our InputModalityDetector subscription.

      this._stopInputModalityDetector.next(); // Clear timeouts for all potentially pending timeouts to prevent the leaks.


      clearTimeout(this._windowFocusTimeoutId);
      clearTimeout(this._originTimeoutId);
    }
  }
  /** Updates all the state on an element once its focus origin has changed. */


  _originChanged(element, origin, elementInfo) {
    this._setClasses(element, origin);

    this._emitOrigin(elementInfo.subject, origin);

    this._lastFocusOrigin = origin;
  }
  /**
   * Collects the `MonitoredElementInfo` of a particular element and
   * all of its ancestors that have enabled `checkChildren`.
   * @param element Element from which to start the search.
   */


  _getClosestElementsInfo(element) {
    const results = [];

    this._elementInfo.forEach((info, currentElement) => {
      if (currentElement === element || info.checkChildren && currentElement.contains(element)) {
        results.push([currentElement, info]);
      }
    });

    return results;
  }

}

FocusMonitor.Éµfac = function FocusMonitor_Factory(t) {
  return new (t || FocusMonitor)(i0.ÉµÉµinject(i0.NgZone), i0.ÉµÉµinject(i1.Platform), i0.ÉµÉµinject(InputModalityDetector), i0.ÉµÉµinject(DOCUMENT, 8), i0.ÉµÉµinject(FOCUS_MONITOR_DEFAULT_OPTIONS, 8));
};

FocusMonitor.Éµprov = /* @__PURE__ */i0.ÉµÉµdefineInjectable({
  token: FocusMonitor,
  factory: FocusMonitor.Éµfac,
  providedIn: 'root'
});

(function () {
  (typeof ngDevMode === "undefined" || ngDevMode) && i0.ÉµsetClassMetadata(FocusMonitor, [{
    type: Injectable,
    args: [{
      providedIn: 'root'
    }]
  }], function () {
    return [{
      type: i0.NgZone
    }, {
      type: i1.Platform
    }, {
      type: InputModalityDetector
    }, {
      type: undefined,
      decorators: [{
        type: Optional
      }, {
        type: Inject,
        args: [DOCUMENT]
      }]
    }, {
      type: undefined,
      decorators: [{
        type: Optional
      }, {
        type: Inject,
        args: [FOCUS_MONITOR_DEFAULT_OPTIONS]
      }]
    }];
  }, null);
})();
/**
 * Directive that determines how a particular element was focused (via keyboard, mouse, touch, or
 * programmatically) and adds corresponding classes to the element.
 *
 * There are two variants of this directive:
 * 1) cdkMonitorElementFocus: does not consider an element to be focused if one of its children is
 *    focused.
 * 2) cdkMonitorSubtreeFocus: considers an element focused if it or any of its children are focused.
 */


class CdkMonitorFocus {
  constructor(_elementRef, _focusMonitor) {
    this._elementRef = _elementRef;
    this._focusMonitor = _focusMonitor;
    this.cdkFocusChange = new EventEmitter();
  }

  ngAfterViewInit() {
    const element = this._elementRef.nativeElement;
    this._monitorSubscription = this._focusMonitor.monitor(element, element.nodeType === 1 && element.hasAttribute('cdkMonitorSubtreeFocus')).subscribe(origin => this.cdkFocusChange.emit(origin));
  }

  ngOnDestroy() {
    this._focusMonitor.stopMonitoring(this._elementRef);

    if (this._monitorSubscription) {
      this._monitorSubscription.unsubscribe();
    }
  }

}

CdkMonitorFocus.Éµfac = function CdkMonitorFocus_Factory(t) {
  return new (t || CdkMonitorFocus)(i0.ÉµÉµdirectiveInject(i0.ElementRef), i0.ÉµÉµdirectiveInject(FocusMonitor));
};

CdkMonitorFocus.Éµdir = /* @__PURE__ */i0.ÉµÉµdefineDirective({
  type: CdkMonitorFocus,
  selectors: [["", "cdkMonitorElementFocus", ""], ["", "cdkMonitorSubtreeFocus", ""]],
  outputs: {
    cdkFocusChange: "cdkFocusChange"
  }
});

(function () {
  (typeof ngDevMode === "undefined" || ngDevMode) && i0.ÉµsetClassMetadata(CdkMonitorFocus, [{
    type: Directive,
    args: [{
      selector: '[cdkMonitorElementFocus], [cdkMonitorSubtreeFocus]'
    }]
  }], function () {
    return [{
      type: i0.ElementRef
    }, {
      type: FocusMonitor
    }];
  }, {
    cdkFocusChange: [{
      type: Output
    }]
  });
})();
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

/** CSS class applied to the document body when in black-on-white high-contrast mode. */


const BLACK_ON_WHITE_CSS_CLASS = 'cdk-high-contrast-black-on-white';
/** CSS class applied to the document body when in white-on-black high-contrast mode. */

const WHITE_ON_BLACK_CSS_CLASS = 'cdk-high-contrast-white-on-black';
/** CSS class applied to the document body when in high-contrast mode. */

const HIGH_CONTRAST_MODE_ACTIVE_CSS_CLASS = 'cdk-high-contrast-active';
/**
 * Service to determine whether the browser is currently in a high-contrast-mode environment.
 *
 * Microsoft Windows supports an accessibility feature called "High Contrast Mode". This mode
 * changes the appearance of all applications, including web applications, to dramatically increase
 * contrast.
 *
 * IE, Edge, and Firefox currently support this mode. Chrome does not support Windows High Contrast
 * Mode. This service does not detect high-contrast mode as added by the Chrome "High Contrast"
 * browser extension.
 */

class HighContrastModeDetector {
  constructor(_platform, document) {
    this._platform = _platform;
    this._document = document;
  }
  /** Gets the current high-contrast-mode for the page. */


  getHighContrastMode() {
    if (!this._platform.isBrowser) {
      return 0
      /* NONE */
      ;
    } // Create a test element with an arbitrary background-color that is neither black nor
    // white; high-contrast mode will coerce the color to either black or white. Also ensure that
    // appending the test element to the DOM does not affect layout by absolutely positioning it


    const testElement = this._document.createElement('div');

    testElement.style.backgroundColor = 'rgb(1,2,3)';
    testElement.style.position = 'absolute';

    this._document.body.appendChild(testElement); // Get the computed style for the background color, collapsing spaces to normalize between
    // browsers. Once we get this color, we no longer need the test element. Access the `window`
    // via the document so we can fake it in tests. Note that we have extra null checks, because
    // this logic will likely run during app bootstrap and throwing can break the entire app.


    const documentWindow = this._document.defaultView || window;
    const computedStyle = documentWindow && documentWindow.getComputedStyle ? documentWindow.getComputedStyle(testElement) : null;
    const computedColor = (computedStyle && computedStyle.backgroundColor || '').replace(/ /g, '');
    testElement.remove();

    switch (computedColor) {
      case 'rgb(0,0,0)':
        return 2
        /* WHITE_ON_BLACK */
        ;

      case 'rgb(255,255,255)':
        return 1
        /* BLACK_ON_WHITE */
        ;
    }

    return 0
    /* NONE */
    ;
  }
  /** Applies CSS classes indicating high-contrast mode to document body (browser-only). */


  _applyBodyHighContrastModeCssClasses() {
    if (!this._hasCheckedHighContrastMode && this._platform.isBrowser && this._document.body) {
      const bodyClasses = this._document.body.classList; // IE11 doesn't support `classList` operations with multiple arguments

      bodyClasses.remove(HIGH_CONTRAST_MODE_ACTIVE_CSS_CLASS);
      bodyClasses.remove(BLACK_ON_WHITE_CSS_CLASS);
      bodyClasses.remove(WHITE_ON_BLACK_CSS_CLASS);
      this._hasCheckedHighContrastMode = true;
      const mode = this.getHighContrastMode();

      if (mode === 1
      /* BLACK_ON_WHITE */
      ) {
        bodyClasses.add(HIGH_CONTRAST_MODE_ACTIVE_CSS_CLASS);
        bodyClasses.add(BLACK_ON_WHITE_CSS_CLASS);
      } else if (mode === 2
      /* WHITE_ON_BLACK */
      ) {
        bodyClasses.add(HIGH_CONTRAST_MODE_ACTIVE_CSS_CLASS);
        bodyClasses.add(WHITE_ON_BLACK_CSS_CLASS);
      }
    }
  }

}

HighContrastModeDetector.Éµfac = function HighContrastModeDetector_Factory(t) {
  return new (t || HighContrastModeDetector)(i0.ÉµÉµinject(i1.Platform), i0.ÉµÉµinject(DOCUMENT));
};

HighContrastModeDetector.Éµprov = /* @__PURE__ */i0.ÉµÉµdefineInjectable({
  token: HighContrastModeDetector,
  factory: HighContrastModeDetector.Éµfac,
  providedIn: 'root'
});

(function () {
  (typeof ngDevMode === "undefined" || ngDevMode) && i0.ÉµsetClassMetadata(HighContrastModeDetector, [{
    type: Injectable,
    args: [{
      providedIn: 'root'
    }]
  }], function () {
    return [{
      type: i1.Platform
    }, {
      type: undefined,
      decorators: [{
        type: Inject,
        args: [DOCUMENT]
      }]
    }];
  }, null);
})();
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */


class A11yModule {
  constructor(highContrastModeDetector) {
    highContrastModeDetector._applyBodyHighContrastModeCssClasses();
  }

}

A11yModule.Éµfac = function A11yModule_Factory(t) {
  return new (t || A11yModule)(i0.ÉµÉµinject(HighContrastModeDetector));
};

A11yModule.Éµmod = /* @__PURE__ */i0.ÉµÉµdefineNgModule({
  type: A11yModule
});
A11yModule.Éµinj = /* @__PURE__ */i0.ÉµÉµdefineInjector({
  imports: [[PlatformModule, ObserversModule]]
});

(function () {
  (typeof ngDevMode === "undefined" || ngDevMode) && i0.ÉµsetClassMetadata(A11yModule, [{
    type: NgModule,
    args: [{
      imports: [PlatformModule, ObserversModule],
      declarations: [CdkAriaLive, CdkTrapFocus, CdkMonitorFocus],
      exports: [CdkAriaLive, CdkTrapFocus, CdkMonitorFocus]
    }]
  }], function () {
    return [{
      type: HighContrastModeDetector
    }];
  }, null);
})();
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

/**
 * Generated bundle index. Do not edit.
 */


export { A11yModule, ActiveDescendantKeyManager, AriaDescriber, CDK_DESCRIBEDBY_HOST_ATTRIBUTE, CDK_DESCRIBEDBY_ID_PREFIX, CdkAriaLive, CdkMonitorFocus, CdkTrapFocus, ConfigurableFocusTrap, ConfigurableFocusTrapFactory, EventListenerFocusTrapInertStrategy, FOCUS_MONITOR_DEFAULT_OPTIONS, FOCUS_TRAP_INERT_STRATEGY, FocusKeyManager, FocusMonitor, FocusTrap, FocusTrapFactory, HighContrastModeDetector, INPUT_MODALITY_DETECTOR_DEFAULT_OPTIONS, INPUT_MODALITY_DETECTOR_OPTIONS, InputModalityDetector, InteractivityChecker, IsFocusableConfig, LIVE_ANNOUNCER_DEFAULT_OPTIONS, LIVE_ANNOUNCER_ELEMENT_TOKEN, LIVE_ANNOUNCER_ELEMENT_TOKEN_FACTORY, ListKeyManager, LiveAnnouncer, MESSAGES_CONTAINER_ID, isFakeMousedownFromScreenReader, isFakeTouchstartFromScreenReader };í   webpack://javascript/esm|./node_modules/@angular-devkit/build-angular/src/babel/webpack-loader.js??ruleSet[1].rules[1].use[0]!./node_modules/source-map-loader/dist/cjs.js??ruleSet[1].rules[2]!./node_modules/@angular/cdk/fesm2020/a11y.mjsdÁ {"version":3,"sources":["webpack://./node_modules/@angular/cdk/fesm2020/a11y.mjs"],"names":["DOCUMENT","i0","Injectable","Inject","QueryList","Directive","Input","InjectionToken","Optional","EventEmitter","Output","NgModule","Subject","Subscription","BehaviorSubject","of","hasModifierKey","A","Z","ZERO","NINE","END","HOME","LEFT_ARROW","RIGHT_ARROW","UP_ARROW","DOWN_ARROW","TAB","ALT","CONTROL","MAC_META","META","SHIFT","tap","debounceTime","filter","map","take","skip","distinctUntilChanged","takeUntil","coerceBooleanProperty","coerceElement","i1","_getFocusedElementPierceShadowDom","normalizePassiveListenerOptions","_getEventTarget","_getShadowRoot","PlatformModule","i1$1","ObserversModule","ID_DELIMITER","addAriaReferencedId","el","attr","id","ids","getAriaReferenceIds","some","existingId","trim","push","setAttribute","join","removeAriaReferencedId","filteredIds","val","length","removeAttribute","getAttribute","match","MESSAGES_CONTAINER_ID","CDK_DESCRIBEDBY_ID_PREFIX","CDK_DESCRIBEDBY_HOST_ATTRIBUTE","nextId","messageRegistry","Map","messagesContainer","AriaDescriber","constructor","_document","describe","hostElement","message","role","_canBeDescribed","key","getKey","setMessageId","set","messageElement","referenceCount","has","_createMessageElement","_isElementDescribedByMessage","_addMessageReference","removeDescription","_isElementNode","_removeMessageReference","registeredMessage","get","_deleteMessageElement","childNodes","_deleteMessagesContainer","ngOnDestroy","describedElements","querySelectorAll","i","_removeCdkDescribedByReferenceIds","clear","createElement","textContent","_createMessagesContainer","appendChild","remove","delete","preExistingContainer","getElementById","style","visibility","classList","add","body","element","originalReferenceIds","indexOf","referenceIds","messageId","trimmedMessage","ariaLabel","nodeType","ELEMENT_NODE","Éµfac","Éµprov","type","args","providedIn","undefined","decorators","ListKeyManager","_items","_activeItemIndex","_activeItem","_wrap","_letterKeyStream","_typeaheadSubscription","EMPTY","_vertical","_allowedModifierKeys","_homeAndEnd","_skipPredicateFn","item","disabled","_pressedLetters","tabOut","change","changes","subscribe","newItems","itemArray","toArray","newIndex","skipPredicate","predicate","withWrap","shouldWrap","withVerticalOrientation","enabled","withHorizontalOrientation","direction","_horizontal","withAllowedModifierKeys","keys","withTypeAhead","debounceInterval","ngDevMode","getLabel","Error","unsubscribe","pipe","letter","inputString","items","_getItemsArray","index","toUpperCase","setActiveItem","withHomeAndEnd","previousActiveItem","updateActiveItem","next","onKeydown","event","keyCode","modifiers","isModifierAllowed","every","modifier","setNextItemActive","setPreviousItemActive","setFirstItemActive","setLastItemActive","toLocaleUpperCase","String","fromCharCode","preventDefault","activeItemIndex","activeItem","isTyping","_setActiveItemByIndex","_setActiveItemByDelta","delta","_setActiveInWrapMode","_setActiveInDefaultMode","fallbackDelta","ActiveDescendantKeyManager","setInactiveStyles","setActiveStyles","FocusKeyManager","arguments","_origin","setFocusOrigin","origin","focus","IsFocusableConfig","ignoreVisibility","InteractivityChecker","_platform","isDisabled","hasAttribute","isVisible","hasGeometry","getComputedStyle","isTabbable","isBrowser","frameElement","getFrameElement","getWindow","getTabIndexValue","nodeName","toLowerCase","tabIndexValue","WEBKIT","IOS","isPotentiallyTabbableIOS","FIREFOX","tabIndex","isFocusable","config","isPotentiallyFocusable","Platform","window","offsetWidth","offsetHeight","getClientRects","isNativeFormElement","isHiddenInput","isInputElement","isAnchorWithHref","isAnchorElement","hasValidTabIndex","isNaN","parseInt","inputType","node","ownerDocument","defaultView","FocusTrap","_element","_checker","_ngZone","deferAnchors","_hasAttached","startAnchorListener","focusLastTabbableElement","endAnchorListener","focusFirstTabbableElement","_enabled","attachAnchors","value","_startAnchor","_endAnchor","_toggleAnchorTabIndex","destroy","startAnchor","endAnchor","removeEventListener","runOutsideAngular","_createAnchor","addEventListener","parentNode","insertBefore","nextSibling","focusInitialElementWhenReady","options","Promise","resolve","_executeOnStable","focusInitialElement","focusFirstTabbableElementWhenReady","focusLastTabbableElementWhenReady","_getRegionBoundary","bound","markers","console","warn","_getFirstTabbableElement","_getLastTabbableElement","redirectToElement","querySelector","focusableChild","hasAttached","root","children","tabbableChild","anchor","isEnabled","toggleAnchors","fn","isStable","onStable","FocusTrapFactory","create","deferCaptureElements","NgZone","CdkTrapFocus","_elementRef","_focusTrapFactory","_previouslyFocusedElement","focusTrap","nativeElement","autoCapture","_autoCapture","ngAfterContentInit","_captureFocus","ngDoCheck","ngOnChanges","autoCaptureChange","firstChange","ElementRef","Éµdir","selector","exportAs","ConfigurableFocusTrap","_focusTrapManager","_inertStrategy","defer","register","deregister","_enable","preventFocus","_disable","allowFocus","FOCUS_TRAP_INERT_STRATEGY","EventListenerFocusTrapInertStrategy","_listener","e","_trapFocus","target","focusTrapRoot","contains","closest","setTimeout","activeElement","FocusTrapManager","_focusTrapStack","ft","stack","splice","ConfigurableFocusTrapFactory","configObject","isFakeMousedownFromScreenReader","offsetX","offsetY","isFakeTouchstartFromScreenReader","touch","touches","changedTouches","identifier","radiusX","radiusY","INPUT_MODALITY_DETECTOR_OPTIONS","INPUT_MODALITY_DETECTOR_DEFAULT_OPTIONS","ignoreKeys","TOUCH_BUFFER_MS","modalityEventListenerOptions","passive","capture","InputModalityDetector","ngZone","document","_mostRecentTarget","_modality","_lastTouchMs","_onKeydown","_options","_onMousedown","Date","now","_onTouchstart","modalityDetected","modalityChanged","mostRecentModality","complete","Document","LIVE_ANNOUNCER_ELEMENT_TOKEN","factory","LIVE_ANNOUNCER_ELEMENT_TOKEN_FACTORY","LIVE_ANNOUNCER_DEFAULT_OPTIONS","LiveAnnouncer","elementToken","_defaultOptions","_liveElement","_createLiveElement","announce","defaultOptions","politeness","duration","clearTimeout","_previousTimeout","elementClass","previousElements","getElementsByClassName","liveEl","CdkAriaLive","_liveAnnouncer","_contentObserver","_politeness","_subscription","observe","elementText","_previousAnnouncedText","ContentObserver","FOCUS_MONITOR_DEFAULT_OPTIONS","captureEventListenerOptions","FocusMonitor","_inputModalityDetector","_windowFocused","_originFromTouchInteraction","_elementInfo","_monitoredElementCount","_rootNodeFocusListenerCount","_windowFocusListener","_windowFocusTimeoutId","_stopInputModalityDetector","_rootNodeFocusAndBlurListener","handler","_onFocus","_onBlur","parentElement","call","_detectionMode","detectionMode","monitor","checkChildren","rootNode","_getDocument","cachedInfo","subject","info","_registerGlobalListeners","stopMonitoring","elementInfo","_setClasses","_removeGlobalListeners","focusVia","focusedElement","_getClosestElementsInfo","forEach","currentElement","_originChanged","_setOrigin","_info","_getWindow","doc","_getFocusOrigin","focusEventTarget","_shouldBeAttributedToTouch","_lastFocusOrigin","toggle","isFromInteraction","_originTimeoutId","ms","relatedTarget","Node","_emitOrigin","run","rootNodeFocusListeners","modality","results","CdkMonitorFocus","_focusMonitor","cdkFocusChange","ngAfterViewInit","_monitorSubscription","emit","BLACK_ON_WHITE_CSS_CLASS","WHITE_ON_BLACK_CSS_CLASS","HIGH_CONTRAST_MODE_ACTIVE_CSS_CLASS","HighContrastModeDetector","getHighContrastMode","testElement","backgroundColor","position","documentWindow","computedStyle","computedColor","replace","_applyBodyHighContrastModeCssClasses","_hasCheckedHighContrastMode","bodyClasses","mode","A11yModule","highContrastModeDetector","Éµmod","Éµinj","imports","declarations","exports"],"mappings":"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","sourcesContent":["import { DOCUMENT } from '@angular/common';\nimport * as i0 from '@angular/core';\nimport { Injectable, Inject, QueryList, Directive, Input, InjectionToken, Optional, EventEmitter, Output, NgModule } from '@angular/core';\nimport { Subject, Subscription, BehaviorSubject, of } from 'rxjs';\nimport { hasModifierKey, A, Z, ZERO, NINE, END, HOME, LEFT_ARROW, RIGHT_ARROW, UP_ARROW, DOWN_ARROW, TAB, ALT, CONTROL, MAC_META, META, SHIFT } from '@angular/cdk/keycodes';\nimport { tap, debounceTime, filter, map, take, skip, distinctUntilChanged, takeUntil } from 'rxjs/operators';\nimport { coerceBooleanProperty, coerceElement } from '@angular/cdk/coercion';\nimport * as i1 from '@angular/cdk/platform';\nimport { _getFocusedElementPierceShadowDom, normalizePassiveListenerOptions, _getEventTarget, _getShadowRoot, PlatformModule } from '@angular/cdk/platform';\nimport * as i1$1 from '@angular/cdk/observers';\nimport { ObserversModule } from '@angular/cdk/observers';\n\n/**\n * @license\n * Copyright Google LLC All Rights Reserved.\n *\n * Use of this source code is governed by an MIT-style license that can be\n * found in the LICENSE file at https://angular.io/license\n */\n/** IDs are delimited by an empty space, as per the spec. */\nconst ID_DELIMITER = ' ';\n/**\n * Adds the given ID to the specified ARIA attribute on an element.\n * Used for attributes such as aria-labelledby, aria-owns, etc.\n */\nfunction addAriaReferencedId(el, attr, id) {\n    const ids = getAriaReferenceIds(el, attr);\n    if (ids.some(existingId => existingId.trim() == id.trim())) {\n        return;\n    }\n    ids.push(id.trim());\n    el.setAttribute(attr, ids.join(ID_DELIMITER));\n}\n/**\n * Removes the given ID from the specified ARIA attribute on an element.\n * Used for attributes such as aria-labelledby, aria-owns, etc.\n */\nfunction removeAriaReferencedId(el, attr, id) {\n    const ids = getAriaReferenceIds(el, attr);\n    const filteredIds = ids.filter(val => val != id.trim());\n    if (filteredIds.length) {\n        el.setAttribute(attr, filteredIds.join(ID_DELIMITER));\n    }\n    else {\n        el.removeAttribute(attr);\n    }\n}\n/**\n * Gets the list of IDs referenced by the given ARIA attribute on an element.\n * Used for attributes such as aria-labelledby, aria-owns, etc.\n */\nfunction getAriaReferenceIds(el, attr) {\n    // Get string array of all individual ids (whitespace delimited) in the attribute value\n    return (el.getAttribute(attr) || '').match(/\\S+/g) || [];\n}\n\n/**\n * @license\n * Copyright Google LLC All Rights Reserved.\n *\n * Use of this source code is governed by an MIT-style license that can be\n * found in the LICENSE file at https://angular.io/license\n */\n/** ID used for the body container where all messages are appended. */\nconst MESSAGES_CONTAINER_ID = 'cdk-describedby-message-container';\n/** ID prefix used for each created message element. */\nconst CDK_DESCRIBEDBY_ID_PREFIX = 'cdk-describedby-message';\n/** Attribute given to each host element that is described by a message element. */\nconst CDK_DESCRIBEDBY_HOST_ATTRIBUTE = 'cdk-describedby-host';\n/** Global incremental identifier for each registered message element. */\nlet nextId = 0;\n/** Global map of all registered message elements that have been placed into the document. */\nconst messageRegistry = new Map();\n/** Container for all registered messages. */\nlet messagesContainer = null;\n/**\n * Utility that creates visually hidden elements with a message content. Useful for elements that\n * want to use aria-describedby to further describe themselves without adding additional visual\n * content.\n */\nclass AriaDescriber {\n    constructor(_document) {\n        this._document = _document;\n    }\n    describe(hostElement, message, role) {\n        if (!this._canBeDescribed(hostElement, message)) {\n            return;\n        }\n        const key = getKey(message, role);\n        if (typeof message !== 'string') {\n            // We need to ensure that the element has an ID.\n            setMessageId(message);\n            messageRegistry.set(key, { messageElement: message, referenceCount: 0 });\n        }\n        else if (!messageRegistry.has(key)) {\n            this._createMessageElement(message, role);\n        }\n        if (!this._isElementDescribedByMessage(hostElement, key)) {\n            this._addMessageReference(hostElement, key);\n        }\n    }\n    removeDescription(hostElement, message, role) {\n        if (!message || !this._isElementNode(hostElement)) {\n            return;\n        }\n        const key = getKey(message, role);\n        if (this._isElementDescribedByMessage(hostElement, key)) {\n            this._removeMessageReference(hostElement, key);\n        }\n        // If the message is a string, it means that it's one that we created for the\n        // consumer so we can remove it safely, otherwise we should leave it in place.\n        if (typeof message === 'string') {\n            const registeredMessage = messageRegistry.get(key);\n            if (registeredMessage && registeredMessage.referenceCount === 0) {\n                this._deleteMessageElement(key);\n            }\n        }\n        if (messagesContainer && messagesContainer.childNodes.length === 0) {\n            this._deleteMessagesContainer();\n        }\n    }\n    /** Unregisters all created message elements and removes the message container. */\n    ngOnDestroy() {\n        const describedElements = this._document.querySelectorAll(`[${CDK_DESCRIBEDBY_HOST_ATTRIBUTE}]`);\n        for (let i = 0; i < describedElements.length; i++) {\n            this._removeCdkDescribedByReferenceIds(describedElements[i]);\n            describedElements[i].removeAttribute(CDK_DESCRIBEDBY_HOST_ATTRIBUTE);\n        }\n        if (messagesContainer) {\n            this._deleteMessagesContainer();\n        }\n        messageRegistry.clear();\n    }\n    /**\n     * Creates a new element in the visually hidden message container element with the message\n     * as its content and adds it to the message registry.\n     */\n    _createMessageElement(message, role) {\n        const messageElement = this._document.createElement('div');\n        setMessageId(messageElement);\n        messageElement.textContent = message;\n        if (role) {\n            messageElement.setAttribute('role', role);\n        }\n        this._createMessagesContainer();\n        messagesContainer.appendChild(messageElement);\n        messageRegistry.set(getKey(message, role), { messageElement, referenceCount: 0 });\n    }\n    /** Deletes the message element from the global messages container. */\n    _deleteMessageElement(key) {\n        const registeredMessage = messageRegistry.get(key);\n        registeredMessage?.messageElement?.remove();\n        messageRegistry.delete(key);\n    }\n    /** Creates the global container for all aria-describedby messages. */\n    _createMessagesContainer() {\n        if (!messagesContainer) {\n            const preExistingContainer = this._document.getElementById(MESSAGES_CONTAINER_ID);\n            // When going from the server to the client, we may end up in a situation where there's\n            // already a container on the page, but we don't have a reference to it. Clear the\n            // old container so we don't get duplicates. Doing this, instead of emptying the previous\n            // container, should be slightly faster.\n            preExistingContainer?.remove();\n            messagesContainer = this._document.createElement('div');\n            messagesContainer.id = MESSAGES_CONTAINER_ID;\n            // We add `visibility: hidden` in order to prevent text in this container from\n            // being searchable by the browser's Ctrl + F functionality.\n            // Screen-readers will still read the description for elements with aria-describedby even\n            // when the description element is not visible.\n            messagesContainer.style.visibility = 'hidden';\n            // Even though we use `visibility: hidden`, we still apply `cdk-visually-hidden` so that\n            // the description element doesn't impact page layout.\n            messagesContainer.classList.add('cdk-visually-hidden');\n            this._document.body.appendChild(messagesContainer);\n        }\n    }\n    /** Deletes the global messages container. */\n    _deleteMessagesContainer() {\n        if (messagesContainer) {\n            messagesContainer.remove();\n            messagesContainer = null;\n        }\n    }\n    /** Removes all cdk-describedby messages that are hosted through the element. */\n    _removeCdkDescribedByReferenceIds(element) {\n        // Remove all aria-describedby reference IDs that are prefixed by CDK_DESCRIBEDBY_ID_PREFIX\n        const originalReferenceIds = getAriaReferenceIds(element, 'aria-describedby').filter(id => id.indexOf(CDK_DESCRIBEDBY_ID_PREFIX) != 0);\n        element.setAttribute('aria-describedby', originalReferenceIds.join(' '));\n    }\n    /**\n     * Adds a message reference to the element using aria-describedby and increments the registered\n     * message's reference count.\n     */\n    _addMessageReference(element, key) {\n        const registeredMessage = messageRegistry.get(key);\n        // Add the aria-describedby reference and set the\n        // describedby_host attribute to mark the element.\n        addAriaReferencedId(element, 'aria-describedby', registeredMessage.messageElement.id);\n        element.setAttribute(CDK_DESCRIBEDBY_HOST_ATTRIBUTE, '');\n        registeredMessage.referenceCount++;\n    }\n    /**\n     * Removes a message reference from the element using aria-describedby\n     * and decrements the registered message's reference count.\n     */\n    _removeMessageReference(element, key) {\n        const registeredMessage = messageRegistry.get(key);\n        registeredMessage.referenceCount--;\n        removeAriaReferencedId(element, 'aria-describedby', registeredMessage.messageElement.id);\n        element.removeAttribute(CDK_DESCRIBEDBY_HOST_ATTRIBUTE);\n    }\n    /** Returns true if the element has been described by the provided message ID. */\n    _isElementDescribedByMessage(element, key) {\n        const referenceIds = getAriaReferenceIds(element, 'aria-describedby');\n        const registeredMessage = messageRegistry.get(key);\n        const messageId = registeredMessage && registeredMessage.messageElement.id;\n        return !!messageId && referenceIds.indexOf(messageId) != -1;\n    }\n    /** Determines whether a message can be described on a particular element. */\n    _canBeDescribed(element, message) {\n        if (!this._isElementNode(element)) {\n            return false;\n        }\n        if (message && typeof message === 'object') {\n            // We'd have to make some assumptions about the description element's text, if the consumer\n            // passed in an element. Assume that if an element is passed in, the consumer has verified\n            // that it can be used as a description.\n            return true;\n        }\n        const trimmedMessage = message == null ? '' : `${message}`.trim();\n        const ariaLabel = element.getAttribute('aria-label');\n        // We shouldn't set descriptions if they're exactly the same as the `aria-label` of the\n        // element, because screen readers will end up reading out the same text twice in a row.\n        return trimmedMessage ? !ariaLabel || ariaLabel.trim() !== trimmedMessage : false;\n    }\n    /** Checks whether a node is an Element node. */\n    _isElementNode(element) {\n        return element.nodeType === this._document.ELEMENT_NODE;\n    }\n}\nAriaDescriber.Éµfac = i0.ÉµÉµngDeclareFactory({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: AriaDescriber, deps: [{ token: DOCUMENT }], target: i0.ÉµÉµFactoryTarget.Injectable });\nAriaDescriber.Éµprov = i0.ÉµÉµngDeclareInjectable({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: AriaDescriber, providedIn: 'root' });\ni0.ÉµÉµngDeclareClassMetadata({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: AriaDescriber, decorators: [{\n            type: Injectable,\n            args: [{ providedIn: 'root' }]\n        }], ctorParameters: function () { return [{ type: undefined, decorators: [{\n                    type: Inject,\n                    args: [DOCUMENT]\n                }] }]; } });\n/** Gets a key that can be used to look messages up in the registry. */\nfunction getKey(message, role) {\n    return typeof message === 'string' ? `${role || ''}/${message}` : message;\n}\n/** Assigns a unique ID to an element, if it doesn't have one already. */\nfunction setMessageId(element) {\n    if (!element.id) {\n        element.id = `${CDK_DESCRIBEDBY_ID_PREFIX}-${nextId++}`;\n    }\n}\n\n/**\n * @license\n * Copyright Google LLC All Rights Reserved.\n *\n * Use of this source code is governed by an MIT-style license that can be\n * found in the LICENSE file at https://angular.io/license\n */\n/**\n * This class manages keyboard events for selectable lists. If you pass it a query list\n * of items, it will set the active item correctly when arrow events occur.\n */\nclass ListKeyManager {\n    constructor(_items) {\n        this._items = _items;\n        this._activeItemIndex = -1;\n        this._activeItem = null;\n        this._wrap = false;\n        this._letterKeyStream = new Subject();\n        this._typeaheadSubscription = Subscription.EMPTY;\n        this._vertical = true;\n        this._allowedModifierKeys = [];\n        this._homeAndEnd = false;\n        /**\n         * Predicate function that can be used to check whether an item should be skipped\n         * by the key manager. By default, disabled items are skipped.\n         */\n        this._skipPredicateFn = (item) => item.disabled;\n        // Buffer for the letters that the user has pressed when the typeahead option is turned on.\n        this._pressedLetters = [];\n        /**\n         * Stream that emits any time the TAB key is pressed, so components can react\n         * when focus is shifted off of the list.\n         */\n        this.tabOut = new Subject();\n        /** Stream that emits whenever the active item of the list manager changes. */\n        this.change = new Subject();\n        // We allow for the items to be an array because, in some cases, the consumer may\n        // not have access to a QueryList of the items they want to manage (e.g. when the\n        // items aren't being collected via `ViewChildren` or `ContentChildren`).\n        if (_items instanceof QueryList) {\n            _items.changes.subscribe((newItems) => {\n                if (this._activeItem) {\n                    const itemArray = newItems.toArray();\n                    const newIndex = itemArray.indexOf(this._activeItem);\n                    if (newIndex > -1 && newIndex !== this._activeItemIndex) {\n                        this._activeItemIndex = newIndex;\n                    }\n                }\n            });\n        }\n    }\n    /**\n     * Sets the predicate function that determines which items should be skipped by the\n     * list key manager.\n     * @param predicate Function that determines whether the given item should be skipped.\n     */\n    skipPredicate(predicate) {\n        this._skipPredicateFn = predicate;\n        return this;\n    }\n    /**\n     * Configures wrapping mode, which determines whether the active item will wrap to\n     * the other end of list when there are no more items in the given direction.\n     * @param shouldWrap Whether the list should wrap when reaching the end.\n     */\n    withWrap(shouldWrap = true) {\n        this._wrap = shouldWrap;\n        return this;\n    }\n    /**\n     * Configures whether the key manager should be able to move the selection vertically.\n     * @param enabled Whether vertical selection should be enabled.\n     */\n    withVerticalOrientation(enabled = true) {\n        this._vertical = enabled;\n        return this;\n    }\n    /**\n     * Configures the key manager to move the selection horizontally.\n     * Passing in `null` will disable horizontal movement.\n     * @param direction Direction in which the selection can be moved.\n     */\n    withHorizontalOrientation(direction) {\n        this._horizontal = direction;\n        return this;\n    }\n    /**\n     * Modifier keys which are allowed to be held down and whose default actions will be prevented\n     * as the user is pressing the arrow keys. Defaults to not allowing any modifier keys.\n     */\n    withAllowedModifierKeys(keys) {\n        this._allowedModifierKeys = keys;\n        return this;\n    }\n    /**\n     * Turns on typeahead mode which allows users to set the active item by typing.\n     * @param debounceInterval Time to wait after the last keystroke before setting the active item.\n     */\n    withTypeAhead(debounceInterval = 200) {\n        if ((typeof ngDevMode === 'undefined' || ngDevMode) &&\n            this._items.length &&\n            this._items.some(item => typeof item.getLabel !== 'function')) {\n            throw Error('ListKeyManager items in typeahead mode must implement the `getLabel` method.');\n        }\n        this._typeaheadSubscription.unsubscribe();\n        // Debounce the presses of non-navigational keys, collect the ones that correspond to letters\n        // and convert those letters back into a string. Afterwards find the first item that starts\n        // with that string and select it.\n        this._typeaheadSubscription = this._letterKeyStream\n            .pipe(tap(letter => this._pressedLetters.push(letter)), debounceTime(debounceInterval), filter(() => this._pressedLetters.length > 0), map(() => this._pressedLetters.join('')))\n            .subscribe(inputString => {\n            const items = this._getItemsArray();\n            // Start at 1 because we want to start searching at the item immediately\n            // following the current active item.\n            for (let i = 1; i < items.length + 1; i++) {\n                const index = (this._activeItemIndex + i) % items.length;\n                const item = items[index];\n                if (!this._skipPredicateFn(item) &&\n                    item.getLabel().toUpperCase().trim().indexOf(inputString) === 0) {\n                    this.setActiveItem(index);\n                    break;\n                }\n            }\n            this._pressedLetters = [];\n        });\n        return this;\n    }\n    /**\n     * Configures the key manager to activate the first and last items\n     * respectively when the Home or End key is pressed.\n     * @param enabled Whether pressing the Home or End key activates the first/last item.\n     */\n    withHomeAndEnd(enabled = true) {\n        this._homeAndEnd = enabled;\n        return this;\n    }\n    setActiveItem(item) {\n        const previousActiveItem = this._activeItem;\n        this.updateActiveItem(item);\n        if (this._activeItem !== previousActiveItem) {\n            this.change.next(this._activeItemIndex);\n        }\n    }\n    /**\n     * Sets the active item depending on the key event passed in.\n     * @param event Keyboard event to be used for determining which element should be active.\n     */\n    onKeydown(event) {\n        const keyCode = event.keyCode;\n        const modifiers = ['altKey', 'ctrlKey', 'metaKey', 'shiftKey'];\n        const isModifierAllowed = modifiers.every(modifier => {\n            return !event[modifier] || this._allowedModifierKeys.indexOf(modifier) > -1;\n        });\n        switch (keyCode) {\n            case TAB:\n                this.tabOut.next();\n                return;\n            case DOWN_ARROW:\n                if (this._vertical && isModifierAllowed) {\n                    this.setNextItemActive();\n                    break;\n                }\n                else {\n                    return;\n                }\n            case UP_ARROW:\n                if (this._vertical && isModifierAllowed) {\n                    this.setPreviousItemActive();\n                    break;\n                }\n                else {\n                    return;\n                }\n            case RIGHT_ARROW:\n                if (this._horizontal && isModifierAllowed) {\n                    this._horizontal === 'rtl' ? this.setPreviousItemActive() : this.setNextItemActive();\n                    break;\n                }\n                else {\n                    return;\n                }\n            case LEFT_ARROW:\n                if (this._horizontal && isModifierAllowed) {\n                    this._horizontal === 'rtl' ? this.setNextItemActive() : this.setPreviousItemActive();\n                    break;\n                }\n                else {\n                    return;\n                }\n            case HOME:\n                if (this._homeAndEnd && isModifierAllowed) {\n                    this.setFirstItemActive();\n                    break;\n                }\n                else {\n                    return;\n                }\n            case END:\n                if (this._homeAndEnd && isModifierAllowed) {\n                    this.setLastItemActive();\n                    break;\n                }\n                else {\n                    return;\n                }\n            default:\n                if (isModifierAllowed || hasModifierKey(event, 'shiftKey')) {\n                    // Attempt to use the `event.key` which also maps it to the user's keyboard language,\n                    // otherwise fall back to resolving alphanumeric characters via the keyCode.\n                    if (event.key && event.key.length === 1) {\n                        this._letterKeyStream.next(event.key.toLocaleUpperCase());\n                    }\n                    else if ((keyCode >= A && keyCode <= Z) || (keyCode >= ZERO && keyCode <= NINE)) {\n                        this._letterKeyStream.next(String.fromCharCode(keyCode));\n                    }\n                }\n                // Note that we return here, in order to avoid preventing\n                // the default action of non-navigational keys.\n                return;\n        }\n        this._pressedLetters = [];\n        event.preventDefault();\n    }\n    /** Index of the currently active item. */\n    get activeItemIndex() {\n        return this._activeItemIndex;\n    }\n    /** The active item. */\n    get activeItem() {\n        return this._activeItem;\n    }\n    /** Gets whether the user is currently typing into the manager using the typeahead feature. */\n    isTyping() {\n        return this._pressedLetters.length > 0;\n    }\n    /** Sets the active item to the first enabled item in the list. */\n    setFirstItemActive() {\n        this._setActiveItemByIndex(0, 1);\n    }\n    /** Sets the active item to the last enabled item in the list. */\n    setLastItemActive() {\n        this._setActiveItemByIndex(this._items.length - 1, -1);\n    }\n    /** Sets the active item to the next enabled item in the list. */\n    setNextItemActive() {\n        this._activeItemIndex < 0 ? this.setFirstItemActive() : this._setActiveItemByDelta(1);\n    }\n    /** Sets the active item to a previous enabled item in the list. */\n    setPreviousItemActive() {\n        this._activeItemIndex < 0 && this._wrap\n            ? this.setLastItemActive()\n            : this._setActiveItemByDelta(-1);\n    }\n    updateActiveItem(item) {\n        const itemArray = this._getItemsArray();\n        const index = typeof item === 'number' ? item : itemArray.indexOf(item);\n        const activeItem = itemArray[index];\n        // Explicitly check for `null` and `undefined` because other falsy values are valid.\n        this._activeItem = activeItem == null ? null : activeItem;\n        this._activeItemIndex = index;\n    }\n    /**\n     * This method sets the active item, given a list of items and the delta between the\n     * currently active item and the new active item. It will calculate differently\n     * depending on whether wrap mode is turned on.\n     */\n    _setActiveItemByDelta(delta) {\n        this._wrap ? this._setActiveInWrapMode(delta) : this._setActiveInDefaultMode(delta);\n    }\n    /**\n     * Sets the active item properly given \"wrap\" mode. In other words, it will continue to move\n     * down the list until it finds an item that is not disabled, and it will wrap if it\n     * encounters either end of the list.\n     */\n    _setActiveInWrapMode(delta) {\n        const items = this._getItemsArray();\n        for (let i = 1; i <= items.length; i++) {\n            const index = (this._activeItemIndex + delta * i + items.length) % items.length;\n            const item = items[index];\n            if (!this._skipPredicateFn(item)) {\n                this.setActiveItem(index);\n                return;\n            }\n        }\n    }\n    /**\n     * Sets the active item properly given the default mode. In other words, it will\n     * continue to move down the list until it finds an item that is not disabled. If\n     * it encounters either end of the list, it will stop and not wrap.\n     */\n    _setActiveInDefaultMode(delta) {\n        this._setActiveItemByIndex(this._activeItemIndex + delta, delta);\n    }\n    /**\n     * Sets the active item to the first enabled item starting at the index specified. If the\n     * item is disabled, it will move in the fallbackDelta direction until it either\n     * finds an enabled item or encounters the end of the list.\n     */\n    _setActiveItemByIndex(index, fallbackDelta) {\n        const items = this._getItemsArray();\n        if (!items[index]) {\n            return;\n        }\n        while (this._skipPredicateFn(items[index])) {\n            index += fallbackDelta;\n            if (!items[index]) {\n                return;\n            }\n        }\n        this.setActiveItem(index);\n    }\n    /** Returns the items as an array. */\n    _getItemsArray() {\n        return this._items instanceof QueryList ? this._items.toArray() : this._items;\n    }\n}\n\n/**\n * @license\n * Copyright Google LLC All Rights Reserved.\n *\n * Use of this source code is governed by an MIT-style license that can be\n * found in the LICENSE file at https://angular.io/license\n */\nclass ActiveDescendantKeyManager extends ListKeyManager {\n    setActiveItem(index) {\n        if (this.activeItem) {\n            this.activeItem.setInactiveStyles();\n        }\n        super.setActiveItem(index);\n        if (this.activeItem) {\n            this.activeItem.setActiveStyles();\n        }\n    }\n}\n\n/**\n * @license\n * Copyright Google LLC All Rights Reserved.\n *\n * Use of this source code is governed by an MIT-style license that can be\n * found in the LICENSE file at https://angular.io/license\n */\nclass FocusKeyManager extends ListKeyManager {\n    constructor() {\n        super(...arguments);\n        this._origin = 'program';\n    }\n    /**\n     * Sets the focus origin that will be passed in to the items for any subsequent `focus` calls.\n     * @param origin Focus origin to be used when focusing items.\n     */\n    setFocusOrigin(origin) {\n        this._origin = origin;\n        return this;\n    }\n    setActiveItem(item) {\n        super.setActiveItem(item);\n        if (this.activeItem) {\n            this.activeItem.focus(this._origin);\n        }\n    }\n}\n\n/**\n * @license\n * Copyright Google LLC All Rights Reserved.\n *\n * Use of this source code is governed by an MIT-style license that can be\n * found in the LICENSE file at https://angular.io/license\n */\n/**\n * Configuration for the isFocusable method.\n */\nclass IsFocusableConfig {\n    constructor() {\n        /**\n         * Whether to count an element as focusable even if it is not currently visible.\n         */\n        this.ignoreVisibility = false;\n    }\n}\n// The InteractivityChecker leans heavily on the ally.js accessibility utilities.\n// Methods like `isTabbable` are only covering specific edge-cases for the browsers which are\n// supported.\n/**\n * Utility for checking the interactivity of an element, such as whether is is focusable or\n * tabbable.\n */\nclass InteractivityChecker {\n    constructor(_platform) {\n        this._platform = _platform;\n    }\n    /**\n     * Gets whether an element is disabled.\n     *\n     * @param element Element to be checked.\n     * @returns Whether the element is disabled.\n     */\n    isDisabled(element) {\n        // This does not capture some cases, such as a non-form control with a disabled attribute or\n        // a form control inside of a disabled form, but should capture the most common cases.\n        return element.hasAttribute('disabled');\n    }\n    /**\n     * Gets whether an element is visible for the purposes of interactivity.\n     *\n     * This will capture states like `display: none` and `visibility: hidden`, but not things like\n     * being clipped by an `overflow: hidden` parent or being outside the viewport.\n     *\n     * @returns Whether the element is visible.\n     */\n    isVisible(element) {\n        return hasGeometry(element) && getComputedStyle(element).visibility === 'visible';\n    }\n    /**\n     * Gets whether an element can be reached via Tab key.\n     * Assumes that the element has already been checked with isFocusable.\n     *\n     * @param element Element to be checked.\n     * @returns Whether the element is tabbable.\n     */\n    isTabbable(element) {\n        // Nothing is tabbable on the server ğŸ˜\n        if (!this._platform.isBrowser) {\n            return false;\n        }\n        const frameElement = getFrameElement(getWindow(element));\n        if (frameElement) {\n            // Frame elements inherit their tabindex onto all child elements.\n            if (getTabIndexValue(frameElement) === -1) {\n                return false;\n            }\n            // Browsers disable tabbing to an element inside of an invisible frame.\n            if (!this.isVisible(frameElement)) {\n                return false;\n            }\n        }\n        let nodeName = element.nodeName.toLowerCase();\n        let tabIndexValue = getTabIndexValue(element);\n        if (element.hasAttribute('contenteditable')) {\n            return tabIndexValue !== -1;\n        }\n        if (nodeName === 'iframe' || nodeName === 'object') {\n            // The frame or object's content may be tabbable depending on the content, but it's\n            // not possibly to reliably detect the content of the frames. We always consider such\n            // elements as non-tabbable.\n            return false;\n        }\n        // In iOS, the browser only considers some specific elements as tabbable.\n        if (this._platform.WEBKIT && this._platform.IOS && !isPotentiallyTabbableIOS(element)) {\n            return false;\n        }\n        if (nodeName === 'audio') {\n            // Audio elements without controls enabled are never tabbable, regardless\n            // of the tabindex attribute explicitly being set.\n            if (!element.hasAttribute('controls')) {\n                return false;\n            }\n            // Audio elements with controls are by default tabbable unless the\n            // tabindex attribute is set to `-1` explicitly.\n            return tabIndexValue !== -1;\n        }\n        if (nodeName === 'video') {\n            // For all video elements, if the tabindex attribute is set to `-1`, the video\n            // is not tabbable. Note: We cannot rely on the default `HTMLElement.tabIndex`\n            // property as that one is set to `-1` in Chrome, Edge and Safari v13.1. The\n            // tabindex attribute is the source of truth here.\n            if (tabIndexValue === -1) {\n                return false;\n            }\n            // If the tabindex is explicitly set, and not `-1` (as per check before), the\n            // video element is always tabbable (regardless of whether it has controls or not).\n            if (tabIndexValue !== null) {\n                return true;\n            }\n            // Otherwise (when no explicit tabindex is set), a video is only tabbable if it\n            // has controls enabled. Firefox is special as videos are always tabbable regardless\n            // of whether there are controls or not.\n            return this._platform.FIREFOX || element.hasAttribute('controls');\n        }\n        return element.tabIndex >= 0;\n    }\n    /**\n     * Gets whether an element can be focused by the user.\n     *\n     * @param element Element to be checked.\n     * @param config The config object with options to customize this method's behavior\n     * @returns Whether the element is focusable.\n     */\n    isFocusable(element, config) {\n        // Perform checks in order of left to most expensive.\n        // Again, naive approach that does not capture many edge cases and browser quirks.\n        return (isPotentiallyFocusable(element) &&\n            !this.isDisabled(element) &&\n            (config?.ignoreVisibility || this.isVisible(element)));\n    }\n}\nInteractivityChecker.Éµfac = i0.ÉµÉµngDeclareFactory({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: InteractivityChecker, deps: [{ token: i1.Platform }], target: i0.ÉµÉµFactoryTarget.Injectable });\nInteractivityChecker.Éµprov = i0.ÉµÉµngDeclareInjectable({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: InteractivityChecker, providedIn: 'root' });\ni0.ÉµÉµngDeclareClassMetadata({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: InteractivityChecker, decorators: [{\n            type: Injectable,\n            args: [{ providedIn: 'root' }]\n        }], ctorParameters: function () { return [{ type: i1.Platform }]; } });\n/**\n * Returns the frame element from a window object. Since browsers like MS Edge throw errors if\n * the frameElement property is being accessed from a different host address, this property\n * should be accessed carefully.\n */\nfunction getFrameElement(window) {\n    try {\n        return window.frameElement;\n    }\n    catch {\n        return null;\n    }\n}\n/** Checks whether the specified element has any geometry / rectangles. */\nfunction hasGeometry(element) {\n    // Use logic from jQuery to check for an invisible element.\n    // See https://github.com/jquery/jquery/blob/master/src/css/hiddenVisibleSelectors.js#L12\n    return !!(element.offsetWidth ||\n        element.offsetHeight ||\n        (typeof element.getClientRects === 'function' && element.getClientRects().length));\n}\n/** Gets whether an element's  */\nfunction isNativeFormElement(element) {\n    let nodeName = element.nodeName.toLowerCase();\n    return (nodeName === 'input' ||\n        nodeName === 'select' ||\n        nodeName === 'button' ||\n        nodeName === 'textarea');\n}\n/** Gets whether an element is an `<input type=\"hidden\">`. */\nfunction isHiddenInput(element) {\n    return isInputElement(element) && element.type == 'hidden';\n}\n/** Gets whether an element is an anchor that has an href attribute. */\nfunction isAnchorWithHref(element) {\n    return isAnchorElement(element) && element.hasAttribute('href');\n}\n/** Gets whether an element is an input element. */\nfunction isInputElement(element) {\n    return element.nodeName.toLowerCase() == 'input';\n}\n/** Gets whether an element is an anchor element. */\nfunction isAnchorElement(element) {\n    return element.nodeName.toLowerCase() == 'a';\n}\n/** Gets whether an element has a valid tabindex. */\nfunction hasValidTabIndex(element) {\n    if (!element.hasAttribute('tabindex') || element.tabIndex === undefined) {\n        return false;\n    }\n    let tabIndex = element.getAttribute('tabindex');\n    return !!(tabIndex && !isNaN(parseInt(tabIndex, 10)));\n}\n/**\n * Returns the parsed tabindex from the element attributes instead of returning the\n * evaluated tabindex from the browsers defaults.\n */\nfunction getTabIndexValue(element) {\n    if (!hasValidTabIndex(element)) {\n        return null;\n    }\n    // See browser issue in Gecko https://bugzilla.mozilla.org/show_bug.cgi?id=1128054\n    const tabIndex = parseInt(element.getAttribute('tabindex') || '', 10);\n    return isNaN(tabIndex) ? -1 : tabIndex;\n}\n/** Checks whether the specified element is potentially tabbable on iOS */\nfunction isPotentiallyTabbableIOS(element) {\n    let nodeName = element.nodeName.toLowerCase();\n    let inputType = nodeName === 'input' && element.type;\n    return (inputType === 'text' ||\n        inputType === 'password' ||\n        nodeName === 'select' ||\n        nodeName === 'textarea');\n}\n/**\n * Gets whether an element is potentially focusable without taking current visible/disabled state\n * into account.\n */\nfunction isPotentiallyFocusable(element) {\n    // Inputs are potentially focusable *unless* they're type=\"hidden\".\n    if (isHiddenInput(element)) {\n        return false;\n    }\n    return (isNativeFormElement(element) ||\n        isAnchorWithHref(element) ||\n        element.hasAttribute('contenteditable') ||\n        hasValidTabIndex(element));\n}\n/** Gets the parent window of a DOM node with regards of being inside of an iframe. */\nfunction getWindow(node) {\n    // ownerDocument is null if `node` itself *is* a document.\n    return (node.ownerDocument && node.ownerDocument.defaultView) || window;\n}\n\n/**\n * @license\n * Copyright Google LLC All Rights Reserved.\n *\n * Use of this source code is governed by an MIT-style license that can be\n * found in the LICENSE file at https://angular.io/license\n */\n/**\n * Class that allows for trapping focus within a DOM element.\n *\n * This class currently uses a relatively simple approach to focus trapping.\n * It assumes that the tab order is the same as DOM order, which is not necessarily true.\n * Things like `tabIndex > 0`, flex `order`, and shadow roots can cause the two to be misaligned.\n *\n * @deprecated Use `ConfigurableFocusTrap` instead.\n * @breaking-change 11.0.0\n */\nclass FocusTrap {\n    constructor(_element, _checker, _ngZone, _document, deferAnchors = false) {\n        this._element = _element;\n        this._checker = _checker;\n        this._ngZone = _ngZone;\n        this._document = _document;\n        this._hasAttached = false;\n        // Event listeners for the anchors. Need to be regular functions so that we can unbind them later.\n        this.startAnchorListener = () => this.focusLastTabbableElement();\n        this.endAnchorListener = () => this.focusFirstTabbableElement();\n        this._enabled = true;\n        if (!deferAnchors) {\n            this.attachAnchors();\n        }\n    }\n    /** Whether the focus trap is active. */\n    get enabled() {\n        return this._enabled;\n    }\n    set enabled(value) {\n        this._enabled = value;\n        if (this._startAnchor && this._endAnchor) {\n            this._toggleAnchorTabIndex(value, this._startAnchor);\n            this._toggleAnchorTabIndex(value, this._endAnchor);\n        }\n    }\n    /** Destroys the focus trap by cleaning up the anchors. */\n    destroy() {\n        const startAnchor = this._startAnchor;\n        const endAnchor = this._endAnchor;\n        if (startAnchor) {\n            startAnchor.removeEventListener('focus', this.startAnchorListener);\n            startAnchor.remove();\n        }\n        if (endAnchor) {\n            endAnchor.removeEventListener('focus', this.endAnchorListener);\n            endAnchor.remove();\n        }\n        this._startAnchor = this._endAnchor = null;\n        this._hasAttached = false;\n    }\n    /**\n     * Inserts the anchors into the DOM. This is usually done automatically\n     * in the constructor, but can be deferred for cases like directives with `*ngIf`.\n     * @returns Whether the focus trap managed to attach successfully. This may not be the case\n     * if the target element isn't currently in the DOM.\n     */\n    attachAnchors() {\n        // If we're not on the browser, there can be no focus to trap.\n        if (this._hasAttached) {\n            return true;\n        }\n        this._ngZone.runOutsideAngular(() => {\n            if (!this._startAnchor) {\n                this._startAnchor = this._createAnchor();\n                this._startAnchor.addEventListener('focus', this.startAnchorListener);\n            }\n            if (!this._endAnchor) {\n                this._endAnchor = this._createAnchor();\n                this._endAnchor.addEventListener('focus', this.endAnchorListener);\n            }\n        });\n        if (this._element.parentNode) {\n            this._element.parentNode.insertBefore(this._startAnchor, this._element);\n            this._element.parentNode.insertBefore(this._endAnchor, this._element.nextSibling);\n            this._hasAttached = true;\n        }\n        return this._hasAttached;\n    }\n    /**\n     * Waits for the zone to stabilize, then focuses the first tabbable element.\n     * @returns Returns a promise that resolves with a boolean, depending\n     * on whether focus was moved successfully.\n     */\n    focusInitialElementWhenReady(options) {\n        return new Promise(resolve => {\n            this._executeOnStable(() => resolve(this.focusInitialElement(options)));\n        });\n    }\n    /**\n     * Waits for the zone to stabilize, then focuses\n     * the first tabbable element within the focus trap region.\n     * @returns Returns a promise that resolves with a boolean, depending\n     * on whether focus was moved successfully.\n     */\n    focusFirstTabbableElementWhenReady(options) {\n        return new Promise(resolve => {\n            this._executeOnStable(() => resolve(this.focusFirstTabbableElement(options)));\n        });\n    }\n    /**\n     * Waits for the zone to stabilize, then focuses\n     * the last tabbable element within the focus trap region.\n     * @returns Returns a promise that resolves with a boolean, depending\n     * on whether focus was moved successfully.\n     */\n    focusLastTabbableElementWhenReady(options) {\n        return new Promise(resolve => {\n            this._executeOnStable(() => resolve(this.focusLastTabbableElement(options)));\n        });\n    }\n    /**\n     * Get the specified boundary element of the trapped region.\n     * @param bound The boundary to get (start or end of trapped region).\n     * @returns The boundary element.\n     */\n    _getRegionBoundary(bound) {\n        // Contains the deprecated version of selector, for temporary backwards comparability.\n        let markers = this._element.querySelectorAll(`[cdk-focus-region-${bound}], ` + `[cdkFocusRegion${bound}], ` + `[cdk-focus-${bound}]`);\n        for (let i = 0; i < markers.length; i++) {\n            // @breaking-change 8.0.0\n            if (markers[i].hasAttribute(`cdk-focus-${bound}`)) {\n                console.warn(`Found use of deprecated attribute 'cdk-focus-${bound}', ` +\n                    `use 'cdkFocusRegion${bound}' instead. The deprecated ` +\n                    `attribute will be removed in 8.0.0.`, markers[i]);\n            }\n            else if (markers[i].hasAttribute(`cdk-focus-region-${bound}`)) {\n                console.warn(`Found use of deprecated attribute 'cdk-focus-region-${bound}', ` +\n                    `use 'cdkFocusRegion${bound}' instead. The deprecated attribute ` +\n                    `will be removed in 8.0.0.`, markers[i]);\n            }\n        }\n        if (bound == 'start') {\n            return markers.length ? markers[0] : this._getFirstTabbableElement(this._element);\n        }\n        return markers.length\n            ? markers[markers.length - 1]\n            : this._getLastTabbableElement(this._element);\n    }\n    /**\n     * Focuses the element that should be focused when the focus trap is initialized.\n     * @returns Whether focus was moved successfully.\n     */\n    focusInitialElement(options) {\n        // Contains the deprecated version of selector, for temporary backwards comparability.\n        const redirectToElement = this._element.querySelector(`[cdk-focus-initial], ` + `[cdkFocusInitial]`);\n        if (redirectToElement) {\n            // @breaking-change 8.0.0\n            if (redirectToElement.hasAttribute(`cdk-focus-initial`)) {\n                console.warn(`Found use of deprecated attribute 'cdk-focus-initial', ` +\n                    `use 'cdkFocusInitial' instead. The deprecated attribute ` +\n                    `will be removed in 8.0.0`, redirectToElement);\n            }\n            // Warn the consumer if the element they've pointed to\n            // isn't focusable, when not in production mode.\n            if ((typeof ngDevMode === 'undefined' || ngDevMode) &&\n                !this._checker.isFocusable(redirectToElement)) {\n                console.warn(`Element matching '[cdkFocusInitial]' is not focusable.`, redirectToElement);\n            }\n            if (!this._checker.isFocusable(redirectToElement)) {\n                const focusableChild = this._getFirstTabbableElement(redirectToElement);\n                focusableChild?.focus(options);\n                return !!focusableChild;\n            }\n            redirectToElement.focus(options);\n            return true;\n        }\n        return this.focusFirstTabbableElement(options);\n    }\n    /**\n     * Focuses the first tabbable element within the focus trap region.\n     * @returns Whether focus was moved successfully.\n     */\n    focusFirstTabbableElement(options) {\n        const redirectToElement = this._getRegionBoundary('start');\n        if (redirectToElement) {\n            redirectToElement.focus(options);\n        }\n        return !!redirectToElement;\n    }\n    /**\n     * Focuses the last tabbable element within the focus trap region.\n     * @returns Whether focus was moved successfully.\n     */\n    focusLastTabbableElement(options) {\n        const redirectToElement = this._getRegionBoundary('end');\n        if (redirectToElement) {\n            redirectToElement.focus(options);\n        }\n        return !!redirectToElement;\n    }\n    /**\n     * Checks whether the focus trap has successfully been attached.\n     */\n    hasAttached() {\n        return this._hasAttached;\n    }\n    /** Get the first tabbable element from a DOM subtree (inclusive). */\n    _getFirstTabbableElement(root) {\n        if (this._checker.isFocusable(root) && this._checker.isTabbable(root)) {\n            return root;\n        }\n        const children = root.children;\n        for (let i = 0; i < children.length; i++) {\n            const tabbableChild = children[i].nodeType === this._document.ELEMENT_NODE\n                ? this._getFirstTabbableElement(children[i])\n                : null;\n            if (tabbableChild) {\n                return tabbableChild;\n            }\n        }\n        return null;\n    }\n    /** Get the last tabbable element from a DOM subtree (inclusive). */\n    _getLastTabbableElement(root) {\n        if (this._checker.isFocusable(root) && this._checker.isTabbable(root)) {\n            return root;\n        }\n        // Iterate in reverse DOM order.\n        const children = root.children;\n        for (let i = children.length - 1; i >= 0; i--) {\n            const tabbableChild = children[i].nodeType === this._document.ELEMENT_NODE\n                ? this._getLastTabbableElement(children[i])\n                : null;\n            if (tabbableChild) {\n                return tabbableChild;\n            }\n        }\n        return null;\n    }\n    /** Creates an anchor element. */\n    _createAnchor() {\n        const anchor = this._document.createElement('div');\n        this._toggleAnchorTabIndex(this._enabled, anchor);\n        anchor.classList.add('cdk-visually-hidden');\n        anchor.classList.add('cdk-focus-trap-anchor');\n        anchor.setAttribute('aria-hidden', 'true');\n        return anchor;\n    }\n    /**\n     * Toggles the `tabindex` of an anchor, based on the enabled state of the focus trap.\n     * @param isEnabled Whether the focus trap is enabled.\n     * @param anchor Anchor on which to toggle the tabindex.\n     */\n    _toggleAnchorTabIndex(isEnabled, anchor) {\n        // Remove the tabindex completely, rather than setting it to -1, because if the\n        // element has a tabindex, the user might still hit it when navigating with the arrow keys.\n        isEnabled ? anchor.setAttribute('tabindex', '0') : anchor.removeAttribute('tabindex');\n    }\n    /**\n     * Toggles the`tabindex` of both anchors to either trap Tab focus or allow it to escape.\n     * @param enabled: Whether the anchors should trap Tab.\n     */\n    toggleAnchors(enabled) {\n        if (this._startAnchor && this._endAnchor) {\n            this._toggleAnchorTabIndex(enabled, this._startAnchor);\n            this._toggleAnchorTabIndex(enabled, this._endAnchor);\n        }\n    }\n    /** Executes a function when the zone is stable. */\n    _executeOnStable(fn) {\n        if (this._ngZone.isStable) {\n            fn();\n        }\n        else {\n            this._ngZone.onStable.pipe(take(1)).subscribe(fn);\n        }\n    }\n}\n/**\n * Factory that allows easy instantiation of focus traps.\n * @deprecated Use `ConfigurableFocusTrapFactory` instead.\n * @breaking-change 11.0.0\n */\nclass FocusTrapFactory {\n    constructor(_checker, _ngZone, _document) {\n        this._checker = _checker;\n        this._ngZone = _ngZone;\n        this._document = _document;\n    }\n    /**\n     * Creates a focus-trapped region around the given element.\n     * @param element The element around which focus will be trapped.\n     * @param deferCaptureElements Defers the creation of focus-capturing elements to be done\n     *     manually by the user.\n     * @returns The created focus trap instance.\n     */\n    create(element, deferCaptureElements = false) {\n        return new FocusTrap(element, this._checker, this._ngZone, this._document, deferCaptureElements);\n    }\n}\nFocusTrapFactory.Éµfac = i0.ÉµÉµngDeclareFactory({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: FocusTrapFactory, deps: [{ token: InteractivityChecker }, { token: i0.NgZone }, { token: DOCUMENT }], target: i0.ÉµÉµFactoryTarget.Injectable });\nFocusTrapFactory.Éµprov = i0.ÉµÉµngDeclareInjectable({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: FocusTrapFactory, providedIn: 'root' });\ni0.ÉµÉµngDeclareClassMetadata({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: FocusTrapFactory, decorators: [{\n            type: Injectable,\n            args: [{ providedIn: 'root' }]\n        }], ctorParameters: function () { return [{ type: InteractivityChecker }, { type: i0.NgZone }, { type: undefined, decorators: [{\n                    type: Inject,\n                    args: [DOCUMENT]\n                }] }]; } });\n/** Directive for trapping focus within a region. */\nclass CdkTrapFocus {\n    constructor(_elementRef, _focusTrapFactory, \n    /**\n     * @deprecated No longer being used. To be removed.\n     * @breaking-change 13.0.0\n     */\n    _document) {\n        this._elementRef = _elementRef;\n        this._focusTrapFactory = _focusTrapFactory;\n        /** Previously focused element to restore focus to upon destroy when using autoCapture. */\n        this._previouslyFocusedElement = null;\n        this.focusTrap = this._focusTrapFactory.create(this._elementRef.nativeElement, true);\n    }\n    /** Whether the focus trap is active. */\n    get enabled() {\n        return this.focusTrap.enabled;\n    }\n    set enabled(value) {\n        this.focusTrap.enabled = coerceBooleanProperty(value);\n    }\n    /**\n     * Whether the directive should automatically move focus into the trapped region upon\n     * initialization and return focus to the previous activeElement upon destruction.\n     */\n    get autoCapture() {\n        return this._autoCapture;\n    }\n    set autoCapture(value) {\n        this._autoCapture = coerceBooleanProperty(value);\n    }\n    ngOnDestroy() {\n        this.focusTrap.destroy();\n        // If we stored a previously focused element when using autoCapture, return focus to that\n        // element now that the trapped region is being destroyed.\n        if (this._previouslyFocusedElement) {\n            this._previouslyFocusedElement.focus();\n            this._previouslyFocusedElement = null;\n        }\n    }\n    ngAfterContentInit() {\n        this.focusTrap.attachAnchors();\n        if (this.autoCapture) {\n            this._captureFocus();\n        }\n    }\n    ngDoCheck() {\n        if (!this.focusTrap.hasAttached()) {\n            this.focusTrap.attachAnchors();\n        }\n    }\n    ngOnChanges(changes) {\n        const autoCaptureChange = changes['autoCapture'];\n        if (autoCaptureChange &&\n            !autoCaptureChange.firstChange &&\n            this.autoCapture &&\n            this.focusTrap.hasAttached()) {\n            this._captureFocus();\n        }\n    }\n    _captureFocus() {\n        this._previouslyFocusedElement = _getFocusedElementPierceShadowDom();\n        this.focusTrap.focusInitialElementWhenReady();\n    }\n}\nCdkTrapFocus.Éµfac = i0.ÉµÉµngDeclareFactory({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: CdkTrapFocus, deps: [{ token: i0.ElementRef }, { token: FocusTrapFactory }, { token: DOCUMENT }], target: i0.ÉµÉµFactoryTarget.Directive });\nCdkTrapFocus.Éµdir = i0.ÉµÉµngDeclareDirective({ minVersion: \"12.0.0\", version: \"13.0.1\", type: CdkTrapFocus, selector: \"[cdkTrapFocus]\", inputs: { enabled: [\"cdkTrapFocus\", \"enabled\"], autoCapture: [\"cdkTrapFocusAutoCapture\", \"autoCapture\"] }, exportAs: [\"cdkTrapFocus\"], usesOnChanges: true, ngImport: i0 });\ni0.ÉµÉµngDeclareClassMetadata({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: CdkTrapFocus, decorators: [{\n            type: Directive,\n            args: [{\n                    selector: '[cdkTrapFocus]',\n                    exportAs: 'cdkTrapFocus',\n                }]\n        }], ctorParameters: function () { return [{ type: i0.ElementRef }, { type: FocusTrapFactory }, { type: undefined, decorators: [{\n                    type: Inject,\n                    args: [DOCUMENT]\n                }] }]; }, propDecorators: { enabled: [{\n                type: Input,\n                args: ['cdkTrapFocus']\n            }], autoCapture: [{\n                type: Input,\n                args: ['cdkTrapFocusAutoCapture']\n            }] } });\n\n/**\n * @license\n * Copyright Google LLC All Rights Reserved.\n *\n * Use of this source code is governed by an MIT-style license that can be\n * found in the LICENSE file at https://angular.io/license\n */\n/**\n * Class that allows for trapping focus within a DOM element.\n *\n * This class uses a strategy pattern that determines how it traps focus.\n * See FocusTrapInertStrategy.\n */\nclass ConfigurableFocusTrap extends FocusTrap {\n    constructor(_element, _checker, _ngZone, _document, _focusTrapManager, _inertStrategy, config) {\n        super(_element, _checker, _ngZone, _document, config.defer);\n        this._focusTrapManager = _focusTrapManager;\n        this._inertStrategy = _inertStrategy;\n        this._focusTrapManager.register(this);\n    }\n    /** Whether the FocusTrap is enabled. */\n    get enabled() {\n        return this._enabled;\n    }\n    set enabled(value) {\n        this._enabled = value;\n        if (this._enabled) {\n            this._focusTrapManager.register(this);\n        }\n        else {\n            this._focusTrapManager.deregister(this);\n        }\n    }\n    /** Notifies the FocusTrapManager that this FocusTrap will be destroyed. */\n    destroy() {\n        this._focusTrapManager.deregister(this);\n        super.destroy();\n    }\n    /** @docs-private Implemented as part of ManagedFocusTrap. */\n    _enable() {\n        this._inertStrategy.preventFocus(this);\n        this.toggleAnchors(true);\n    }\n    /** @docs-private Implemented as part of ManagedFocusTrap. */\n    _disable() {\n        this._inertStrategy.allowFocus(this);\n        this.toggleAnchors(false);\n    }\n}\n\n/**\n * @license\n * Copyright Google LLC All Rights Reserved.\n *\n * Use of this source code is governed by an MIT-style license that can be\n * found in the LICENSE file at https://angular.io/license\n */\n\n/**\n * @license\n * Copyright Google LLC All Rights Reserved.\n *\n * Use of this source code is governed by an MIT-style license that can be\n * found in the LICENSE file at https://angular.io/license\n */\n/** The injection token used to specify the inert strategy. */\nconst FOCUS_TRAP_INERT_STRATEGY = new InjectionToken('FOCUS_TRAP_INERT_STRATEGY');\n\n/**\n * @license\n * Copyright Google LLC All Rights Reserved.\n *\n * Use of this source code is governed by an MIT-style license that can be\n * found in the LICENSE file at https://angular.io/license\n */\n/**\n * Lightweight FocusTrapInertStrategy that adds a document focus event\n * listener to redirect focus back inside the FocusTrap.\n */\nclass EventListenerFocusTrapInertStrategy {\n    constructor() {\n        /** Focus event handler. */\n        this._listener = null;\n    }\n    /** Adds a document event listener that keeps focus inside the FocusTrap. */\n    preventFocus(focusTrap) {\n        // Ensure there's only one listener per document\n        if (this._listener) {\n            focusTrap._document.removeEventListener('focus', this._listener, true);\n        }\n        this._listener = (e) => this._trapFocus(focusTrap, e);\n        focusTrap._ngZone.runOutsideAngular(() => {\n            focusTrap._document.addEventListener('focus', this._listener, true);\n        });\n    }\n    /** Removes the event listener added in preventFocus. */\n    allowFocus(focusTrap) {\n        if (!this._listener) {\n            return;\n        }\n        focusTrap._document.removeEventListener('focus', this._listener, true);\n        this._listener = null;\n    }\n    /**\n     * Refocuses the first element in the FocusTrap if the focus event target was outside\n     * the FocusTrap.\n     *\n     * This is an event listener callback. The event listener is added in runOutsideAngular,\n     * so all this code runs outside Angular as well.\n     */\n    _trapFocus(focusTrap, event) {\n        const target = event.target;\n        const focusTrapRoot = focusTrap._element;\n        // Don't refocus if target was in an overlay, because the overlay might be associated\n        // with an element inside the FocusTrap, ex. mat-select.\n        if (target && !focusTrapRoot.contains(target) && !target.closest?.('div.cdk-overlay-pane')) {\n            // Some legacy FocusTrap usages have logic that focuses some element on the page\n            // just before FocusTrap is destroyed. For backwards compatibility, wait\n            // to be sure FocusTrap is still enabled before refocusing.\n            setTimeout(() => {\n                // Check whether focus wasn't put back into the focus trap while the timeout was pending.\n                if (focusTrap.enabled && !focusTrapRoot.contains(focusTrap._document.activeElement)) {\n                    focusTrap.focusFirstTabbableElement();\n                }\n            });\n        }\n    }\n}\n\n/**\n * @license\n * Copyright Google LLC All Rights Reserved.\n *\n * Use of this source code is governed by an MIT-style license that can be\n * found in the LICENSE file at https://angular.io/license\n */\n/** Injectable that ensures only the most recently enabled FocusTrap is active. */\nclass FocusTrapManager {\n    constructor() {\n        // A stack of the FocusTraps on the page. Only the FocusTrap at the\n        // top of the stack is active.\n        this._focusTrapStack = [];\n    }\n    /**\n     * Disables the FocusTrap at the top of the stack, and then pushes\n     * the new FocusTrap onto the stack.\n     */\n    register(focusTrap) {\n        // Dedupe focusTraps that register multiple times.\n        this._focusTrapStack = this._focusTrapStack.filter(ft => ft !== focusTrap);\n        let stack = this._focusTrapStack;\n        if (stack.length) {\n            stack[stack.length - 1]._disable();\n        }\n        stack.push(focusTrap);\n        focusTrap._enable();\n    }\n    /**\n     * Removes the FocusTrap from the stack, and activates the\n     * FocusTrap that is the new top of the stack.\n     */\n    deregister(focusTrap) {\n        focusTrap._disable();\n        const stack = this._focusTrapStack;\n        const i = stack.indexOf(focusTrap);\n        if (i !== -1) {\n            stack.splice(i, 1);\n            if (stack.length) {\n                stack[stack.length - 1]._enable();\n            }\n        }\n    }\n}\nFocusTrapManager.Éµfac = i0.ÉµÉµngDeclareFactory({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: FocusTrapManager, deps: [], target: i0.ÉµÉµFactoryTarget.Injectable });\nFocusTrapManager.Éµprov = i0.ÉµÉµngDeclareInjectable({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: FocusTrapManager, providedIn: 'root' });\ni0.ÉµÉµngDeclareClassMetadata({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: FocusTrapManager, decorators: [{\n            type: Injectable,\n            args: [{ providedIn: 'root' }]\n        }] });\n\n/**\n * @license\n * Copyright Google LLC All Rights Reserved.\n *\n * Use of this source code is governed by an MIT-style license that can be\n * found in the LICENSE file at https://angular.io/license\n */\n/** Factory that allows easy instantiation of configurable focus traps. */\nclass ConfigurableFocusTrapFactory {\n    constructor(_checker, _ngZone, _focusTrapManager, _document, _inertStrategy) {\n        this._checker = _checker;\n        this._ngZone = _ngZone;\n        this._focusTrapManager = _focusTrapManager;\n        this._document = _document;\n        // TODO split up the strategies into different modules, similar to DateAdapter.\n        this._inertStrategy = _inertStrategy || new EventListenerFocusTrapInertStrategy();\n    }\n    create(element, config = { defer: false }) {\n        let configObject;\n        if (typeof config === 'boolean') {\n            configObject = { defer: config };\n        }\n        else {\n            configObject = config;\n        }\n        return new ConfigurableFocusTrap(element, this._checker, this._ngZone, this._document, this._focusTrapManager, this._inertStrategy, configObject);\n    }\n}\nConfigurableFocusTrapFactory.Éµfac = i0.ÉµÉµngDeclareFactory({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: ConfigurableFocusTrapFactory, deps: [{ token: InteractivityChecker }, { token: i0.NgZone }, { token: FocusTrapManager }, { token: DOCUMENT }, { token: FOCUS_TRAP_INERT_STRATEGY, optional: true }], target: i0.ÉµÉµFactoryTarget.Injectable });\nConfigurableFocusTrapFactory.Éµprov = i0.ÉµÉµngDeclareInjectable({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: ConfigurableFocusTrapFactory, providedIn: 'root' });\ni0.ÉµÉµngDeclareClassMetadata({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: ConfigurableFocusTrapFactory, decorators: [{\n            type: Injectable,\n            args: [{ providedIn: 'root' }]\n        }], ctorParameters: function () { return [{ type: InteractivityChecker }, { type: i0.NgZone }, { type: FocusTrapManager }, { type: undefined, decorators: [{\n                    type: Inject,\n                    args: [DOCUMENT]\n                }] }, { type: undefined, decorators: [{\n                    type: Optional\n                }, {\n                    type: Inject,\n                    args: [FOCUS_TRAP_INERT_STRATEGY]\n                }] }]; } });\n\n/**\n * @license\n * Copyright Google LLC All Rights Reserved.\n *\n * Use of this source code is governed by an MIT-style license that can be\n * found in the LICENSE file at https://angular.io/license\n */\n/** Gets whether an event could be a faked `mousedown` event dispatched by a screen reader. */\nfunction isFakeMousedownFromScreenReader(event) {\n    // Some screen readers will dispatch a fake `mousedown` event when pressing enter or space on\n    // a clickable element. We can distinguish these events when both `offsetX` and `offsetY` are\n    // zero. Note that there's an edge case where the user could click the 0x0 spot of the screen\n    // themselves, but that is unlikely to contain interaction elements. Historically we used to\n    // check `event.buttons === 0`, however that no longer works on recent versions of NVDA.\n    return event.offsetX === 0 && event.offsetY === 0;\n}\n/** Gets whether an event could be a faked `touchstart` event dispatched by a screen reader. */\nfunction isFakeTouchstartFromScreenReader(event) {\n    const touch = (event.touches && event.touches[0]) || (event.changedTouches && event.changedTouches[0]);\n    // A fake `touchstart` can be distinguished from a real one by looking at the `identifier`\n    // which is typically >= 0 on a real device versus -1 from a screen reader. Just to be safe,\n    // we can also look at `radiusX` and `radiusY`. This behavior was observed against a Windows 10\n    // device with a touch screen running NVDA v2020.4 and Firefox 85 or Chrome 88.\n    return (!!touch &&\n        touch.identifier === -1 &&\n        (touch.radiusX == null || touch.radiusX === 1) &&\n        (touch.radiusY == null || touch.radiusY === 1));\n}\n\n/**\n * @license\n * Copyright Google LLC All Rights Reserved.\n *\n * Use of this source code is governed by an MIT-style license that can be\n * found in the LICENSE file at https://angular.io/license\n */\n/**\n * Injectable options for the InputModalityDetector. These are shallowly merged with the default\n * options.\n */\nconst INPUT_MODALITY_DETECTOR_OPTIONS = new InjectionToken('cdk-input-modality-detector-options');\n/**\n * Default options for the InputModalityDetector.\n *\n * Modifier keys are ignored by default (i.e. when pressed won't cause the service to detect\n * keyboard input modality) for two reasons:\n *\n * 1. Modifier keys are commonly used with mouse to perform actions such as 'right click' or 'open\n *    in new tab', and are thus less representative of actual keyboard interaction.\n * 2. VoiceOver triggers some keyboard events when linearly navigating with Control + Option (but\n *    confusingly not with Caps Lock). Thus, to have parity with other screen readers, we ignore\n *    these keys so as to not update the input modality.\n *\n * Note that we do not by default ignore the right Meta key on Safari because it has the same key\n * code as the ContextMenu key on other browsers. When we switch to using event.key, we can\n * distinguish between the two.\n */\nconst INPUT_MODALITY_DETECTOR_DEFAULT_OPTIONS = {\n    ignoreKeys: [ALT, CONTROL, MAC_META, META, SHIFT],\n};\n/**\n * The amount of time needed to pass after a touchstart event in order for a subsequent mousedown\n * event to be attributed as mouse and not touch.\n *\n * This is the value used by AngularJS Material. Through trial and error (on iPhone 6S) they found\n * that a value of around 650ms seems appropriate.\n */\nconst TOUCH_BUFFER_MS = 650;\n/**\n * Event listener options that enable capturing and also mark the listener as passive if the browser\n * supports it.\n */\nconst modalityEventListenerOptions = normalizePassiveListenerOptions({\n    passive: true,\n    capture: true,\n});\n/**\n * Service that detects the user's input modality.\n *\n * This service does not update the input modality when a user navigates with a screen reader\n * (e.g. linear navigation with VoiceOver, object navigation / browse mode with NVDA, virtual PC\n * cursor mode with JAWS). This is in part due to technical limitations (i.e. keyboard events do not\n * fire as expected in these modes) but is also arguably the correct behavior. Navigating with a\n * screen reader is akin to visually scanning a page, and should not be interpreted as actual user\n * input interaction.\n *\n * When a user is not navigating but *interacting* with a screen reader, this service attempts to\n * update the input modality to keyboard, but in general this service's behavior is largely\n * undefined.\n */\nclass InputModalityDetector {\n    constructor(_platform, ngZone, document, options) {\n        this._platform = _platform;\n        /**\n         * The most recently detected input modality event target. Is null if no input modality has been\n         * detected or if the associated event target is null for some unknown reason.\n         */\n        this._mostRecentTarget = null;\n        /** The underlying BehaviorSubject that emits whenever an input modality is detected. */\n        this._modality = new BehaviorSubject(null);\n        /**\n         * The timestamp of the last touch input modality. Used to determine whether mousedown events\n         * should be attributed to mouse or touch.\n         */\n        this._lastTouchMs = 0;\n        /**\n         * Handles keydown events. Must be an arrow function in order to preserve the context when it gets\n         * bound.\n         */\n        this._onKeydown = (event) => {\n            // If this is one of the keys we should ignore, then ignore it and don't update the input\n            // modality to keyboard.\n            if (this._options?.ignoreKeys?.some(keyCode => keyCode === event.keyCode)) {\n                return;\n            }\n            this._modality.next('keyboard');\n            this._mostRecentTarget = _getEventTarget(event);\n        };\n        /**\n         * Handles mousedown events. Must be an arrow function in order to preserve the context when it\n         * gets bound.\n         */\n        this._onMousedown = (event) => {\n            // Touches trigger both touch and mouse events, so we need to distinguish between mouse events\n            // that were triggered via mouse vs touch. To do so, check if the mouse event occurs closely\n            // after the previous touch event.\n            if (Date.now() - this._lastTouchMs < TOUCH_BUFFER_MS) {\n                return;\n            }\n            // Fake mousedown events are fired by some screen readers when controls are activated by the\n            // screen reader. Attribute them to keyboard input modality.\n            this._modality.next(isFakeMousedownFromScreenReader(event) ? 'keyboard' : 'mouse');\n            this._mostRecentTarget = _getEventTarget(event);\n        };\n        /**\n         * Handles touchstart events. Must be an arrow function in order to preserve the context when it\n         * gets bound.\n         */\n        this._onTouchstart = (event) => {\n            // Same scenario as mentioned in _onMousedown, but on touch screen devices, fake touchstart\n            // events are fired. Again, attribute to keyboard input modality.\n            if (isFakeTouchstartFromScreenReader(event)) {\n                this._modality.next('keyboard');\n                return;\n            }\n            // Store the timestamp of this touch event, as it's used to distinguish between mouse events\n            // triggered via mouse vs touch.\n            this._lastTouchMs = Date.now();\n            this._modality.next('touch');\n            this._mostRecentTarget = _getEventTarget(event);\n        };\n        this._options = {\n            ...INPUT_MODALITY_DETECTOR_DEFAULT_OPTIONS,\n            ...options,\n        };\n        // Skip the first emission as it's null.\n        this.modalityDetected = this._modality.pipe(skip(1));\n        this.modalityChanged = this.modalityDetected.pipe(distinctUntilChanged());\n        // If we're not in a browser, this service should do nothing, as there's no relevant input\n        // modality to detect.\n        if (_platform.isBrowser) {\n            ngZone.runOutsideAngular(() => {\n                document.addEventListener('keydown', this._onKeydown, modalityEventListenerOptions);\n                document.addEventListener('mousedown', this._onMousedown, modalityEventListenerOptions);\n                document.addEventListener('touchstart', this._onTouchstart, modalityEventListenerOptions);\n            });\n        }\n    }\n    /** The most recently detected input modality. */\n    get mostRecentModality() {\n        return this._modality.value;\n    }\n    ngOnDestroy() {\n        this._modality.complete();\n        if (this._platform.isBrowser) {\n            document.removeEventListener('keydown', this._onKeydown, modalityEventListenerOptions);\n            document.removeEventListener('mousedown', this._onMousedown, modalityEventListenerOptions);\n            document.removeEventListener('touchstart', this._onTouchstart, modalityEventListenerOptions);\n        }\n    }\n}\nInputModalityDetector.Éµfac = i0.ÉµÉµngDeclareFactory({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: InputModalityDetector, deps: [{ token: i1.Platform }, { token: i0.NgZone }, { token: DOCUMENT }, { token: INPUT_MODALITY_DETECTOR_OPTIONS, optional: true }], target: i0.ÉµÉµFactoryTarget.Injectable });\nInputModalityDetector.Éµprov = i0.ÉµÉµngDeclareInjectable({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: InputModalityDetector, providedIn: 'root' });\ni0.ÉµÉµngDeclareClassMetadata({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: InputModalityDetector, decorators: [{\n            type: Injectable,\n            args: [{ providedIn: 'root' }]\n        }], ctorParameters: function () { return [{ type: i1.Platform }, { type: i0.NgZone }, { type: Document, decorators: [{\n                    type: Inject,\n                    args: [DOCUMENT]\n                }] }, { type: undefined, decorators: [{\n                    type: Optional\n                }, {\n                    type: Inject,\n                    args: [INPUT_MODALITY_DETECTOR_OPTIONS]\n                }] }]; } });\n\n/**\n * @license\n * Copyright Google LLC All Rights Reserved.\n *\n * Use of this source code is governed by an MIT-style license that can be\n * found in the LICENSE file at https://angular.io/license\n */\nconst LIVE_ANNOUNCER_ELEMENT_TOKEN = new InjectionToken('liveAnnouncerElement', {\n    providedIn: 'root',\n    factory: LIVE_ANNOUNCER_ELEMENT_TOKEN_FACTORY,\n});\n/** @docs-private */\nfunction LIVE_ANNOUNCER_ELEMENT_TOKEN_FACTORY() {\n    return null;\n}\n/** Injection token that can be used to configure the default options for the LiveAnnouncer. */\nconst LIVE_ANNOUNCER_DEFAULT_OPTIONS = new InjectionToken('LIVE_ANNOUNCER_DEFAULT_OPTIONS');\n\n/**\n * @license\n * Copyright Google LLC All Rights Reserved.\n *\n * Use of this source code is governed by an MIT-style license that can be\n * found in the LICENSE file at https://angular.io/license\n */\nclass LiveAnnouncer {\n    constructor(elementToken, _ngZone, _document, _defaultOptions) {\n        this._ngZone = _ngZone;\n        this._defaultOptions = _defaultOptions;\n        // We inject the live element and document as `any` because the constructor signature cannot\n        // reference browser globals (HTMLElement, Document) on non-browser environments, since having\n        // a class decorator causes TypeScript to preserve the constructor signature types.\n        this._document = _document;\n        this._liveElement = elementToken || this._createLiveElement();\n    }\n    announce(message, ...args) {\n        const defaultOptions = this._defaultOptions;\n        let politeness;\n        let duration;\n        if (args.length === 1 && typeof args[0] === 'number') {\n            duration = args[0];\n        }\n        else {\n            [politeness, duration] = args;\n        }\n        this.clear();\n        clearTimeout(this._previousTimeout);\n        if (!politeness) {\n            politeness =\n                defaultOptions && defaultOptions.politeness ? defaultOptions.politeness : 'polite';\n        }\n        if (duration == null && defaultOptions) {\n            duration = defaultOptions.duration;\n        }\n        // TODO: ensure changing the politeness works on all environments we support.\n        this._liveElement.setAttribute('aria-live', politeness);\n        // This 100ms timeout is necessary for some browser + screen-reader combinations:\n        // - Both JAWS and NVDA over IE11 will not announce anything without a non-zero timeout.\n        // - With Chrome and IE11 with NVDA or JAWS, a repeated (identical) message won't be read a\n        //   second time without clearing and then using a non-zero delay.\n        // (using JAWS 17 at time of this writing).\n        return this._ngZone.runOutsideAngular(() => {\n            return new Promise(resolve => {\n                clearTimeout(this._previousTimeout);\n                this._previousTimeout = setTimeout(() => {\n                    this._liveElement.textContent = message;\n                    resolve();\n                    if (typeof duration === 'number') {\n                        this._previousTimeout = setTimeout(() => this.clear(), duration);\n                    }\n                }, 100);\n            });\n        });\n    }\n    /**\n     * Clears the current text from the announcer element. Can be used to prevent\n     * screen readers from reading the text out again while the user is going\n     * through the page landmarks.\n     */\n    clear() {\n        if (this._liveElement) {\n            this._liveElement.textContent = '';\n        }\n    }\n    ngOnDestroy() {\n        clearTimeout(this._previousTimeout);\n        this._liveElement?.remove();\n        this._liveElement = null;\n    }\n    _createLiveElement() {\n        const elementClass = 'cdk-live-announcer-element';\n        const previousElements = this._document.getElementsByClassName(elementClass);\n        const liveEl = this._document.createElement('div');\n        // Remove any old containers. This can happen when coming in from a server-side-rendered page.\n        for (let i = 0; i < previousElements.length; i++) {\n            previousElements[i].remove();\n        }\n        liveEl.classList.add(elementClass);\n        liveEl.classList.add('cdk-visually-hidden');\n        liveEl.setAttribute('aria-atomic', 'true');\n        liveEl.setAttribute('aria-live', 'polite');\n        this._document.body.appendChild(liveEl);\n        return liveEl;\n    }\n}\nLiveAnnouncer.Éµfac = i0.ÉµÉµngDeclareFactory({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: LiveAnnouncer, deps: [{ token: LIVE_ANNOUNCER_ELEMENT_TOKEN, optional: true }, { token: i0.NgZone }, { token: DOCUMENT }, { token: LIVE_ANNOUNCER_DEFAULT_OPTIONS, optional: true }], target: i0.ÉµÉµFactoryTarget.Injectable });\nLiveAnnouncer.Éµprov = i0.ÉµÉµngDeclareInjectable({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: LiveAnnouncer, providedIn: 'root' });\ni0.ÉµÉµngDeclareClassMetadata({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: LiveAnnouncer, decorators: [{\n            type: Injectable,\n            args: [{ providedIn: 'root' }]\n        }], ctorParameters: function () { return [{ type: undefined, decorators: [{\n                    type: Optional\n                }, {\n                    type: Inject,\n                    args: [LIVE_ANNOUNCER_ELEMENT_TOKEN]\n                }] }, { type: i0.NgZone }, { type: undefined, decorators: [{\n                    type: Inject,\n                    args: [DOCUMENT]\n                }] }, { type: undefined, decorators: [{\n                    type: Optional\n                }, {\n                    type: Inject,\n                    args: [LIVE_ANNOUNCER_DEFAULT_OPTIONS]\n                }] }]; } });\n/**\n * A directive that works similarly to aria-live, but uses the LiveAnnouncer to ensure compatibility\n * with a wider range of browsers and screen readers.\n */\nclass CdkAriaLive {\n    constructor(_elementRef, _liveAnnouncer, _contentObserver, _ngZone) {\n        this._elementRef = _elementRef;\n        this._liveAnnouncer = _liveAnnouncer;\n        this._contentObserver = _contentObserver;\n        this._ngZone = _ngZone;\n        this._politeness = 'polite';\n    }\n    /** The aria-live politeness level to use when announcing messages. */\n    get politeness() {\n        return this._politeness;\n    }\n    set politeness(value) {\n        this._politeness = value === 'off' || value === 'assertive' ? value : 'polite';\n        if (this._politeness === 'off') {\n            if (this._subscription) {\n                this._subscription.unsubscribe();\n                this._subscription = null;\n            }\n        }\n        else if (!this._subscription) {\n            this._subscription = this._ngZone.runOutsideAngular(() => {\n                return this._contentObserver.observe(this._elementRef).subscribe(() => {\n                    // Note that we use textContent here, rather than innerText, in order to avoid a reflow.\n                    const elementText = this._elementRef.nativeElement.textContent;\n                    // The `MutationObserver` fires also for attribute\n                    // changes which we don't want to announce.\n                    if (elementText !== this._previousAnnouncedText) {\n                        this._liveAnnouncer.announce(elementText, this._politeness);\n                        this._previousAnnouncedText = elementText;\n                    }\n                });\n            });\n        }\n    }\n    ngOnDestroy() {\n        if (this._subscription) {\n            this._subscription.unsubscribe();\n        }\n    }\n}\nCdkAriaLive.Éµfac = i0.ÉµÉµngDeclareFactory({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: CdkAriaLive, deps: [{ token: i0.ElementRef }, { token: LiveAnnouncer }, { token: i1$1.ContentObserver }, { token: i0.NgZone }], target: i0.ÉµÉµFactoryTarget.Directive });\nCdkAriaLive.Éµdir = i0.ÉµÉµngDeclareDirective({ minVersion: \"12.0.0\", version: \"13.0.1\", type: CdkAriaLive, selector: \"[cdkAriaLive]\", inputs: { politeness: [\"cdkAriaLive\", \"politeness\"] }, exportAs: [\"cdkAriaLive\"], ngImport: i0 });\ni0.ÉµÉµngDeclareClassMetadata({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: CdkAriaLive, decorators: [{\n            type: Directive,\n            args: [{\n                    selector: '[cdkAriaLive]',\n                    exportAs: 'cdkAriaLive',\n                }]\n        }], ctorParameters: function () { return [{ type: i0.ElementRef }, { type: LiveAnnouncer }, { type: i1$1.ContentObserver }, { type: i0.NgZone }]; }, propDecorators: { politeness: [{\n                type: Input,\n                args: ['cdkAriaLive']\n            }] } });\n\n/**\n * @license\n * Copyright Google LLC All Rights Reserved.\n *\n * Use of this source code is governed by an MIT-style license that can be\n * found in the LICENSE file at https://angular.io/license\n */\n/** InjectionToken for FocusMonitorOptions. */\nconst FOCUS_MONITOR_DEFAULT_OPTIONS = new InjectionToken('cdk-focus-monitor-default-options');\n/**\n * Event listener options that enable capturing and also\n * mark the listener as passive if the browser supports it.\n */\nconst captureEventListenerOptions = normalizePassiveListenerOptions({\n    passive: true,\n    capture: true,\n});\n/** Monitors mouse and keyboard events to determine the cause of focus events. */\nclass FocusMonitor {\n    constructor(_ngZone, _platform, _inputModalityDetector, \n    /** @breaking-change 11.0.0 make document required */\n    document, options) {\n        this._ngZone = _ngZone;\n        this._platform = _platform;\n        this._inputModalityDetector = _inputModalityDetector;\n        /** The focus origin that the next focus event is a result of. */\n        this._origin = null;\n        /** Whether the window has just been focused. */\n        this._windowFocused = false;\n        /**\n         * Whether the origin was determined via a touch interaction. Necessary as properly attributing\n         * focus events to touch interactions requires special logic.\n         */\n        this._originFromTouchInteraction = false;\n        /** Map of elements being monitored to their info. */\n        this._elementInfo = new Map();\n        /** The number of elements currently being monitored. */\n        this._monitoredElementCount = 0;\n        /**\n         * Keeps track of the root nodes to which we've currently bound a focus/blur handler,\n         * as well as the number of monitored elements that they contain. We have to treat focus/blur\n         * handlers differently from the rest of the events, because the browser won't emit events\n         * to the document when focus moves inside of a shadow root.\n         */\n        this._rootNodeFocusListenerCount = new Map();\n        /**\n         * Event listener for `focus` events on the window.\n         * Needs to be an arrow function in order to preserve the context when it gets bound.\n         */\n        this._windowFocusListener = () => {\n            // Make a note of when the window regains focus, so we can\n            // restore the origin info for the focused element.\n            this._windowFocused = true;\n            this._windowFocusTimeoutId = setTimeout(() => (this._windowFocused = false));\n        };\n        /** Subject for stopping our InputModalityDetector subscription. */\n        this._stopInputModalityDetector = new Subject();\n        /**\n         * Event listener for `focus` and 'blur' events on the document.\n         * Needs to be an arrow function in order to preserve the context when it gets bound.\n         */\n        this._rootNodeFocusAndBlurListener = (event) => {\n            const target = _getEventTarget(event);\n            const handler = event.type === 'focus' ? this._onFocus : this._onBlur;\n            // We need to walk up the ancestor chain in order to support `checkChildren`.\n            for (let element = target; element; element = element.parentElement) {\n                handler.call(this, event, element);\n            }\n        };\n        this._document = document;\n        this._detectionMode = options?.detectionMode || 0 /* IMMEDIATE */;\n    }\n    monitor(element, checkChildren = false) {\n        const nativeElement = coerceElement(element);\n        // Do nothing if we're not on the browser platform or the passed in node isn't an element.\n        if (!this._platform.isBrowser || nativeElement.nodeType !== 1) {\n            return of(null);\n        }\n        // If the element is inside the shadow DOM, we need to bind our focus/blur listeners to\n        // the shadow root, rather than the `document`, because the browser won't emit focus events\n        // to the `document`, if focus is moving within the same shadow root.\n        const rootNode = _getShadowRoot(nativeElement) || this._getDocument();\n        const cachedInfo = this._elementInfo.get(nativeElement);\n        // Check if we're already monitoring this element.\n        if (cachedInfo) {\n            if (checkChildren) {\n                // TODO(COMP-318): this can be problematic, because it'll turn all non-checkChildren\n                // observers into ones that behave as if `checkChildren` was turned on. We need a more\n                // robust solution.\n                cachedInfo.checkChildren = true;\n            }\n            return cachedInfo.subject;\n        }\n        // Create monitored element info.\n        const info = {\n            checkChildren: checkChildren,\n            subject: new Subject(),\n            rootNode,\n        };\n        this._elementInfo.set(nativeElement, info);\n        this._registerGlobalListeners(info);\n        return info.subject;\n    }\n    stopMonitoring(element) {\n        const nativeElement = coerceElement(element);\n        const elementInfo = this._elementInfo.get(nativeElement);\n        if (elementInfo) {\n            elementInfo.subject.complete();\n            this._setClasses(nativeElement);\n            this._elementInfo.delete(nativeElement);\n            this._removeGlobalListeners(elementInfo);\n        }\n    }\n    focusVia(element, origin, options) {\n        const nativeElement = coerceElement(element);\n        const focusedElement = this._getDocument().activeElement;\n        // If the element is focused already, calling `focus` again won't trigger the event listener\n        // which means that the focus classes won't be updated. If that's the case, update the classes\n        // directly without waiting for an event.\n        if (nativeElement === focusedElement) {\n            this._getClosestElementsInfo(nativeElement).forEach(([currentElement, info]) => this._originChanged(currentElement, origin, info));\n        }\n        else {\n            this._setOrigin(origin);\n            // `focus` isn't available on the server\n            if (typeof nativeElement.focus === 'function') {\n                nativeElement.focus(options);\n            }\n        }\n    }\n    ngOnDestroy() {\n        this._elementInfo.forEach((_info, element) => this.stopMonitoring(element));\n    }\n    /** Access injected document if available or fallback to global document reference */\n    _getDocument() {\n        return this._document || document;\n    }\n    /** Use defaultView of injected document if available or fallback to global window reference */\n    _getWindow() {\n        const doc = this._getDocument();\n        return doc.defaultView || window;\n    }\n    _getFocusOrigin(focusEventTarget) {\n        if (this._origin) {\n            // If the origin was realized via a touch interaction, we need to perform additional checks\n            // to determine whether the focus origin should be attributed to touch or program.\n            if (this._originFromTouchInteraction) {\n                return this._shouldBeAttributedToTouch(focusEventTarget) ? 'touch' : 'program';\n            }\n            else {\n                return this._origin;\n            }\n        }\n        // If the window has just regained focus, we can restore the most recent origin from before the\n        // window blurred. Otherwise, we've reached the point where we can't identify the source of the\n        // focus. This typically means one of two things happened:\n        //\n        // 1) The element was programmatically focused, or\n        // 2) The element was focused via screen reader navigation (which generally doesn't fire\n        //    events).\n        //\n        // Because we can't distinguish between these two cases, we default to setting `program`.\n        return this._windowFocused && this._lastFocusOrigin ? this._lastFocusOrigin : 'program';\n    }\n    /**\n     * Returns whether the focus event should be attributed to touch. Recall that in IMMEDIATE mode, a\n     * touch origin isn't immediately reset at the next tick (see _setOrigin). This means that when we\n     * handle a focus event following a touch interaction, we need to determine whether (1) the focus\n     * event was directly caused by the touch interaction or (2) the focus event was caused by a\n     * subsequent programmatic focus call triggered by the touch interaction.\n     * @param focusEventTarget The target of the focus event under examination.\n     */\n    _shouldBeAttributedToTouch(focusEventTarget) {\n        // Please note that this check is not perfect. Consider the following edge case:\n        //\n        // <div #parent tabindex=\"0\">\n        //   <div #child tabindex=\"0\" (click)=\"#parent.focus()\"></div>\n        // </div>\n        //\n        // Suppose there is a FocusMonitor in IMMEDIATE mode attached to #parent. When the user touches\n        // #child, #parent is programmatically focused. This code will attribute the focus to touch\n        // instead of program. This is a relatively minor edge-case that can be worked around by using\n        // focusVia(parent, 'program') to focus #parent.\n        return (this._detectionMode === 1 /* EVENTUAL */ ||\n            !!focusEventTarget?.contains(this._inputModalityDetector._mostRecentTarget));\n    }\n    /**\n     * Sets the focus classes on the element based on the given focus origin.\n     * @param element The element to update the classes on.\n     * @param origin The focus origin.\n     */\n    _setClasses(element, origin) {\n        element.classList.toggle('cdk-focused', !!origin);\n        element.classList.toggle('cdk-touch-focused', origin === 'touch');\n        element.classList.toggle('cdk-keyboard-focused', origin === 'keyboard');\n        element.classList.toggle('cdk-mouse-focused', origin === 'mouse');\n        element.classList.toggle('cdk-program-focused', origin === 'program');\n    }\n    /**\n     * Updates the focus origin. If we're using immediate detection mode, we schedule an async\n     * function to clear the origin at the end of a timeout. The duration of the timeout depends on\n     * the origin being set.\n     * @param origin The origin to set.\n     * @param isFromInteraction Whether we are setting the origin from an interaction event.\n     */\n    _setOrigin(origin, isFromInteraction = false) {\n        this._ngZone.runOutsideAngular(() => {\n            this._origin = origin;\n            this._originFromTouchInteraction = origin === 'touch' && isFromInteraction;\n            // If we're in IMMEDIATE mode, reset the origin at the next tick (or in `TOUCH_BUFFER_MS` ms\n            // for a touch event). We reset the origin at the next tick because Firefox focuses one tick\n            // after the interaction event. We wait `TOUCH_BUFFER_MS` ms before resetting the origin for\n            // a touch event because when a touch event is fired, the associated focus event isn't yet in\n            // the event queue. Before doing so, clear any pending timeouts.\n            if (this._detectionMode === 0 /* IMMEDIATE */) {\n                clearTimeout(this._originTimeoutId);\n                const ms = this._originFromTouchInteraction ? TOUCH_BUFFER_MS : 1;\n                this._originTimeoutId = setTimeout(() => (this._origin = null), ms);\n            }\n        });\n    }\n    /**\n     * Handles focus events on a registered element.\n     * @param event The focus event.\n     * @param element The monitored element.\n     */\n    _onFocus(event, element) {\n        // NOTE(mmalerba): We currently set the classes based on the focus origin of the most recent\n        // focus event affecting the monitored element. If we want to use the origin of the first event\n        // instead we should check for the cdk-focused class here and return if the element already has\n        // it. (This only matters for elements that have includesChildren = true).\n        // If we are not counting child-element-focus as focused, make sure that the event target is the\n        // monitored element itself.\n        const elementInfo = this._elementInfo.get(element);\n        const focusEventTarget = _getEventTarget(event);\n        if (!elementInfo || (!elementInfo.checkChildren && element !== focusEventTarget)) {\n            return;\n        }\n        this._originChanged(element, this._getFocusOrigin(focusEventTarget), elementInfo);\n    }\n    /**\n     * Handles blur events on a registered element.\n     * @param event The blur event.\n     * @param element The monitored element.\n     */\n    _onBlur(event, element) {\n        // If we are counting child-element-focus as focused, make sure that we aren't just blurring in\n        // order to focus another child of the monitored element.\n        const elementInfo = this._elementInfo.get(element);\n        if (!elementInfo ||\n            (elementInfo.checkChildren &&\n                event.relatedTarget instanceof Node &&\n                element.contains(event.relatedTarget))) {\n            return;\n        }\n        this._setClasses(element);\n        this._emitOrigin(elementInfo.subject, null);\n    }\n    _emitOrigin(subject, origin) {\n        this._ngZone.run(() => subject.next(origin));\n    }\n    _registerGlobalListeners(elementInfo) {\n        if (!this._platform.isBrowser) {\n            return;\n        }\n        const rootNode = elementInfo.rootNode;\n        const rootNodeFocusListeners = this._rootNodeFocusListenerCount.get(rootNode) || 0;\n        if (!rootNodeFocusListeners) {\n            this._ngZone.runOutsideAngular(() => {\n                rootNode.addEventListener('focus', this._rootNodeFocusAndBlurListener, captureEventListenerOptions);\n                rootNode.addEventListener('blur', this._rootNodeFocusAndBlurListener, captureEventListenerOptions);\n            });\n        }\n        this._rootNodeFocusListenerCount.set(rootNode, rootNodeFocusListeners + 1);\n        // Register global listeners when first element is monitored.\n        if (++this._monitoredElementCount === 1) {\n            // Note: we listen to events in the capture phase so we\n            // can detect them even if the user stops propagation.\n            this._ngZone.runOutsideAngular(() => {\n                const window = this._getWindow();\n                window.addEventListener('focus', this._windowFocusListener);\n            });\n            // The InputModalityDetector is also just a collection of global listeners.\n            this._inputModalityDetector.modalityDetected\n                .pipe(takeUntil(this._stopInputModalityDetector))\n                .subscribe(modality => {\n                this._setOrigin(modality, true /* isFromInteraction */);\n            });\n        }\n    }\n    _removeGlobalListeners(elementInfo) {\n        const rootNode = elementInfo.rootNode;\n        if (this._rootNodeFocusListenerCount.has(rootNode)) {\n            const rootNodeFocusListeners = this._rootNodeFocusListenerCount.get(rootNode);\n            if (rootNodeFocusListeners > 1) {\n                this._rootNodeFocusListenerCount.set(rootNode, rootNodeFocusListeners - 1);\n            }\n            else {\n                rootNode.removeEventListener('focus', this._rootNodeFocusAndBlurListener, captureEventListenerOptions);\n                rootNode.removeEventListener('blur', this._rootNodeFocusAndBlurListener, captureEventListenerOptions);\n                this._rootNodeFocusListenerCount.delete(rootNode);\n            }\n        }\n        // Unregister global listeners when last element is unmonitored.\n        if (!--this._monitoredElementCount) {\n            const window = this._getWindow();\n            window.removeEventListener('focus', this._windowFocusListener);\n            // Equivalently, stop our InputModalityDetector subscription.\n            this._stopInputModalityDetector.next();\n            // Clear timeouts for all potentially pending timeouts to prevent the leaks.\n            clearTimeout(this._windowFocusTimeoutId);\n            clearTimeout(this._originTimeoutId);\n        }\n    }\n    /** Updates all the state on an element once its focus origin has changed. */\n    _originChanged(element, origin, elementInfo) {\n        this._setClasses(element, origin);\n        this._emitOrigin(elementInfo.subject, origin);\n        this._lastFocusOrigin = origin;\n    }\n    /**\n     * Collects the `MonitoredElementInfo` of a particular element and\n     * all of its ancestors that have enabled `checkChildren`.\n     * @param element Element from which to start the search.\n     */\n    _getClosestElementsInfo(element) {\n        const results = [];\n        this._elementInfo.forEach((info, currentElement) => {\n            if (currentElement === element || (info.checkChildren && currentElement.contains(element))) {\n                results.push([currentElement, info]);\n            }\n        });\n        return results;\n    }\n}\nFocusMonitor.Éµfac = i0.ÉµÉµngDeclareFactory({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: FocusMonitor, deps: [{ token: i0.NgZone }, { token: i1.Platform }, { token: InputModalityDetector }, { token: DOCUMENT, optional: true }, { token: FOCUS_MONITOR_DEFAULT_OPTIONS, optional: true }], target: i0.ÉµÉµFactoryTarget.Injectable });\nFocusMonitor.Éµprov = i0.ÉµÉµngDeclareInjectable({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: FocusMonitor, providedIn: 'root' });\ni0.ÉµÉµngDeclareClassMetadata({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: FocusMonitor, decorators: [{\n            type: Injectable,\n            args: [{ providedIn: 'root' }]\n        }], ctorParameters: function () { return [{ type: i0.NgZone }, { type: i1.Platform }, { type: InputModalityDetector }, { type: undefined, decorators: [{\n                    type: Optional\n                }, {\n                    type: Inject,\n                    args: [DOCUMENT]\n                }] }, { type: undefined, decorators: [{\n                    type: Optional\n                }, {\n                    type: Inject,\n                    args: [FOCUS_MONITOR_DEFAULT_OPTIONS]\n                }] }]; } });\n/**\n * Directive that determines how a particular element was focused (via keyboard, mouse, touch, or\n * programmatically) and adds corresponding classes to the element.\n *\n * There are two variants of this directive:\n * 1) cdkMonitorElementFocus: does not consider an element to be focused if one of its children is\n *    focused.\n * 2) cdkMonitorSubtreeFocus: considers an element focused if it or any of its children are focused.\n */\nclass CdkMonitorFocus {\n    constructor(_elementRef, _focusMonitor) {\n        this._elementRef = _elementRef;\n        this._focusMonitor = _focusMonitor;\n        this.cdkFocusChange = new EventEmitter();\n    }\n    ngAfterViewInit() {\n        const element = this._elementRef.nativeElement;\n        this._monitorSubscription = this._focusMonitor\n            .monitor(element, element.nodeType === 1 && element.hasAttribute('cdkMonitorSubtreeFocus'))\n            .subscribe(origin => this.cdkFocusChange.emit(origin));\n    }\n    ngOnDestroy() {\n        this._focusMonitor.stopMonitoring(this._elementRef);\n        if (this._monitorSubscription) {\n            this._monitorSubscription.unsubscribe();\n        }\n    }\n}\nCdkMonitorFocus.Éµfac = i0.ÉµÉµngDeclareFactory({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: CdkMonitorFocus, deps: [{ token: i0.ElementRef }, { token: FocusMonitor }], target: i0.ÉµÉµFactoryTarget.Directive });\nCdkMonitorFocus.Éµdir = i0.ÉµÉµngDeclareDirective({ minVersion: \"12.0.0\", version: \"13.0.1\", type: CdkMonitorFocus, selector: \"[cdkMonitorElementFocus], [cdkMonitorSubtreeFocus]\", outputs: { cdkFocusChange: \"cdkFocusChange\" }, ngImport: i0 });\ni0.ÉµÉµngDeclareClassMetadata({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: CdkMonitorFocus, decorators: [{\n            type: Directive,\n            args: [{\n                    selector: '[cdkMonitorElementFocus], [cdkMonitorSubtreeFocus]',\n                }]\n        }], ctorParameters: function () { return [{ type: i0.ElementRef }, { type: FocusMonitor }]; }, propDecorators: { cdkFocusChange: [{\n                type: Output\n            }] } });\n\n/**\n * @license\n * Copyright Google LLC All Rights Reserved.\n *\n * Use of this source code is governed by an MIT-style license that can be\n * found in the LICENSE file at https://angular.io/license\n */\n/** CSS class applied to the document body when in black-on-white high-contrast mode. */\nconst BLACK_ON_WHITE_CSS_CLASS = 'cdk-high-contrast-black-on-white';\n/** CSS class applied to the document body when in white-on-black high-contrast mode. */\nconst WHITE_ON_BLACK_CSS_CLASS = 'cdk-high-contrast-white-on-black';\n/** CSS class applied to the document body when in high-contrast mode. */\nconst HIGH_CONTRAST_MODE_ACTIVE_CSS_CLASS = 'cdk-high-contrast-active';\n/**\n * Service to determine whether the browser is currently in a high-contrast-mode environment.\n *\n * Microsoft Windows supports an accessibility feature called \"High Contrast Mode\". This mode\n * changes the appearance of all applications, including web applications, to dramatically increase\n * contrast.\n *\n * IE, Edge, and Firefox currently support this mode. Chrome does not support Windows High Contrast\n * Mode. This service does not detect high-contrast mode as added by the Chrome \"High Contrast\"\n * browser extension.\n */\nclass HighContrastModeDetector {\n    constructor(_platform, document) {\n        this._platform = _platform;\n        this._document = document;\n    }\n    /** Gets the current high-contrast-mode for the page. */\n    getHighContrastMode() {\n        if (!this._platform.isBrowser) {\n            return 0 /* NONE */;\n        }\n        // Create a test element with an arbitrary background-color that is neither black nor\n        // white; high-contrast mode will coerce the color to either black or white. Also ensure that\n        // appending the test element to the DOM does not affect layout by absolutely positioning it\n        const testElement = this._document.createElement('div');\n        testElement.style.backgroundColor = 'rgb(1,2,3)';\n        testElement.style.position = 'absolute';\n        this._document.body.appendChild(testElement);\n        // Get the computed style for the background color, collapsing spaces to normalize between\n        // browsers. Once we get this color, we no longer need the test element. Access the `window`\n        // via the document so we can fake it in tests. Note that we have extra null checks, because\n        // this logic will likely run during app bootstrap and throwing can break the entire app.\n        const documentWindow = this._document.defaultView || window;\n        const computedStyle = documentWindow && documentWindow.getComputedStyle\n            ? documentWindow.getComputedStyle(testElement)\n            : null;\n        const computedColor = ((computedStyle && computedStyle.backgroundColor) || '').replace(/ /g, '');\n        testElement.remove();\n        switch (computedColor) {\n            case 'rgb(0,0,0)':\n                return 2 /* WHITE_ON_BLACK */;\n            case 'rgb(255,255,255)':\n                return 1 /* BLACK_ON_WHITE */;\n        }\n        return 0 /* NONE */;\n    }\n    /** Applies CSS classes indicating high-contrast mode to document body (browser-only). */\n    _applyBodyHighContrastModeCssClasses() {\n        if (!this._hasCheckedHighContrastMode && this._platform.isBrowser && this._document.body) {\n            const bodyClasses = this._document.body.classList;\n            // IE11 doesn't support `classList` operations with multiple arguments\n            bodyClasses.remove(HIGH_CONTRAST_MODE_ACTIVE_CSS_CLASS);\n            bodyClasses.remove(BLACK_ON_WHITE_CSS_CLASS);\n            bodyClasses.remove(WHITE_ON_BLACK_CSS_CLASS);\n            this._hasCheckedHighContrastMode = true;\n            const mode = this.getHighContrastMode();\n            if (mode === 1 /* BLACK_ON_WHITE */) {\n                bodyClasses.add(HIGH_CONTRAST_MODE_ACTIVE_CSS_CLASS);\n                bodyClasses.add(BLACK_ON_WHITE_CSS_CLASS);\n            }\n            else if (mode === 2 /* WHITE_ON_BLACK */) {\n                bodyClasses.add(HIGH_CONTRAST_MODE_ACTIVE_CSS_CLASS);\n                bodyClasses.add(WHITE_ON_BLACK_CSS_CLASS);\n            }\n        }\n    }\n}\nHighContrastModeDetector.Éµfac = i0.ÉµÉµngDeclareFactory({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: HighContrastModeDetector, deps: [{ token: i1.Platform }, { token: DOCUMENT }], target: i0.ÉµÉµFactoryTarget.Injectable });\nHighContrastModeDetector.Éµprov = i0.ÉµÉµngDeclareInjectable({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: HighContrastModeDetector, providedIn: 'root' });\ni0.ÉµÉµngDeclareClassMetadata({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: HighContrastModeDetector, decorators: [{\n            type: Injectable,\n            args: [{ providedIn: 'root' }]\n        }], ctorParameters: function () { return [{ type: i1.Platform }, { type: undefined, decorators: [{\n                    type: Inject,\n                    args: [DOCUMENT]\n                }] }]; } });\n\n/**\n * @license\n * Copyright Google LLC All Rights Reserved.\n *\n * Use of this source code is governed by an MIT-style license that can be\n * found in the LICENSE file at https://angular.io/license\n */\nclass A11yModule {\n    constructor(highContrastModeDetector) {\n        highContrastModeDetector._applyBodyHighContrastModeCssClasses();\n    }\n}\nA11yModule.Éµfac = i0.ÉµÉµngDeclareFactory({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: A11yModule, deps: [{ token: HighContrastModeDetector }], target: i0.ÉµÉµFactoryTarget.NgModule });\nA11yModule.Éµmod = i0.ÉµÉµngDeclareNgModule({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: A11yModule, declarations: [CdkAriaLive, CdkTrapFocus, CdkMonitorFocus], imports: [PlatformModule, ObserversModule], exports: [CdkAriaLive, CdkTrapFocus, CdkMonitorFocus] });\nA11yModule.Éµinj = i0.ÉµÉµngDeclareInjector({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: A11yModule, imports: [[PlatformModule, ObserversModule]] });\ni0.ÉµÉµngDeclareClassMetadata({ minVersion: \"12.0.0\", version: \"13.0.1\", ngImport: i0, type: A11yModule, decorators: [{\n            type: NgModule,\n            args: [{\n                    imports: [PlatformModule, ObserversModule],\n                    declarations: [CdkAriaLive, CdkTrapFocus, CdkMonitorFocus],\n                    exports: [CdkAriaLive, CdkTrapFocus, CdkMonitorFocus],\n                }]\n        }], ctorParameters: function () { return [{ type: HighContrastModeDetector }]; } });\n\n/**\n * @license\n * Copyright Google LLC All Rights Reserved.\n *\n * Use of this source code is governed by an MIT-style license that can be\n * found in the LICENSE file at https://angular.io/license\n */\n\n/**\n * @license\n * Copyright Google LLC All Rights Reserved.\n *\n * Use of this source code is governed by an MIT-style license that can be\n * found in the LICENSE file at https://angular.io/license\n */\n\n/**\n * Generated bundle index. Do not edit.\n */\n\nexport { A11yModule, ActiveDescendantKeyManager, AriaDescriber, CDK_DESCRIBEDBY_HOST_ATTRIBUTE, CDK_DESCRIBEDBY_ID_PREFIX, CdkAriaLive, CdkMonitorFocus, CdkTrapFocus, ConfigurableFocusTrap, ConfigurableFocusTrapFactory, EventListenerFocusTrapInertStrategy, FOCUS_MONITOR_DEFAULT_OPTIONS, FOCUS_TRAP_INERT_STRATEGY, FocusKeyManager, FocusMonitor, FocusTrap, FocusTrapFactory, HighContrastModeDetector, INPUT_MODALITY_DETECTOR_DEFAULT_OPTIONS, INPUT_MODALITY_DETECTOR_OPTIONS, InputModalityDetector, InteractivityChecker, IsFocusableConfig, LIVE_ANNOUNCER_DEFAULT_OPTIONS, LIVE_ANNOUNCER_ELEMENT_TOKEN, LIVE_ANNOUNCER_ELEMENT_TOKEN_FACTORY, ListKeyManager, LiveAnnouncer, MESSAGES_CONTAINER_ID, isFakeMousedownFromScreenReader, isFakeTouchstartFromScreenReader };\n"],"file":"x"}@Ö    c*,OQ_Ú   Ü       Ë  Í  9  ;  ‡  ‰  ´  ¶  Q  S    ƒ  »  ¼*  Æ*  È*  Ï*  ı*  +  ª+  ½+  Û+  ä+  p,  u,  ‡,  ,  j0  _p0  —0  ¨0  	3  3  ~3  „3  š4  ¢4  ?  ?  J?  U?  j?  o?  ™?  ›?  F  F  >F  GF  ëF  òF  šG  ¤G  †H  H  qI  tI  J  J  èJ  _õJ  `L  `L  pL  pL  €L  ƒL  “L  –L  [  [  Nt  Xt  Zt  dt  ™t  ­t  Tu  gu  Œu  •u  óu  ıu  æ«  é«  ˆ¯  ’¯  «¯  µ¯  ·¯  ¿¯  Ã¯  _Í¯  Ï¯  Ö¯  °  °  º°  Í°  î°  ÷°  ±  ‡±  Ì±  Ñ±  ã±  ê±  Ğ´  ä´  ¶  -¶  ¥¹  Å¹  ]º  pº  rº  ~º  ‚º  •º  ªº  ½º  ¿º  Æº  òº  _»  ê»   ¼  L¼  _¼  |¼  „¼  
½  ½  ½  †½  ˜½  Ÿ½  Ö½  Ú½  "¾  &¾  AÆ  NÆ  FÕ  ZÕ  ùÕ  Ö  -Ö  6Ö  EÛ  OÛ  hÛ  rÛ  tÛ  |Û  €Û  _ŠÛ  ŸÛ  ©Û  «Û  ²Û  ¶Û  ÀÛ  Ü  .Ü  åÜ  øÜ  %İ  .İ  ¶İ  ¾İ  )Ş  .Ş  @Ş  GŞ  –Ş  Ş  ¸Ş  ½Ş  çæ  ôæ  ¾ê  Àê  Ãê  Éê  Ìê  Óê  Öê  _Ùê  Üê  àê  Üì  úì  ò  ò  ³ô  Áô  á÷  ï÷  Àú  Îú  ”û  —û  Ôû  çû  S  ]  _  i  m  w  y    …    ‘  ˜  œ  ¦  ÿ  _ ¼ Ï õ ş \ f } … É Î à ç 6 = X ] ¨ µ   ° º Ş è ê ò ö    	  _ g {  ' E N Ú á ü  O W œ ¡ ³ º 	  + 0 F Y [ g k ~  £ ¥ ¸ ¼ _Ï Ñ Ù   ü   +  3  ·  Ã  ı  ! '! /! _! c! »" È" ’# °# q+ w+ u, ƒ, m. y. 3/ 4/ \0 i0 Õ2 _Û2 ¦3 ²3 5 5 MM [M U ‰U "^ ,^ .^ 6^ :^ D^ F^ P^ T^ ^^ x^ ‚^ „^ ‹^ ’^ œ^ ê^ ş^ •_ ¨_ Å_ Î_ ,` _4` K` U` Å` Ì` ç` ì` ş` a Ta [a va {a 4d ?d lf f f f ‘f ¤f àf óf æg ùg h !h «h ·h i i y _y y $y (y 2y 4y ;y ty ˆy 7z Jz sz |z Úz äz ){ .{ @{ G{ } } b} t} °} Â} Ó} à} ã} ñ} >~ Q~ l~ Fs~ “~  ~ £~ ±~ c [„ €€€€€€€€€€€8   _angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµÉµinject"]µ_angular_common__WEBPACK_IMPORTED_MODULE_1__.DOCUMENTB   _angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµÉµdefineInjectable"]@   _angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµsetClassMetadata"]µ_angular_core__WEBPACK_IMPORTED_MODULE_0__.Injectable±_angular_core__WEBPACK_IMPORTED_MODULE_0__.Injectû©rxjs__WEBPACK_IMPORTED_MODULE_2__.Subject´rxjs__WEBPACK_IMPORTED_MODULE_3__.Subscription.EMPTYşş´_angular_core__WEBPACK_IMPORTED_MODULE_0__.QueryList³(0,rxjs_operators__WEBPACK_IMPORTED_MODULE_4__.tap)¼(0,rxjs_operators__WEBPACK_IMPORTED_MODULE_5__.debounceTime)¶(0,rxjs_operators__WEBPACK_IMPORTED_MODULE_6__.filter)³(0,rxjs_operators__WEBPACK_IMPORTED_MODULE_7__.map)¶_angular_cdk_keycodes__WEBPACK_IMPORTED_MODULE_8__.TAB½_angular_cdk_keycodes__WEBPACK_IMPORTED_MODULE_8__.DOWN_ARROW»_angular_cdk_keycodes__WEBPACK_IMPORTED_MODULE_8__.UP_ARROW¾_angular_cdk_keycodes__WEBPACK_IMPORTED_MODULE_8__.RIGHT_ARROW½_angular_cdk_keycodes__WEBPACK_IMPORTED_MODULE_8__.LEFT_ARROW·_angular_cdk_keycodes__WEBPACK_IMPORTED_MODULE_8__.HOME¶_angular_cdk_keycodes__WEBPACK_IMPORTED_MODULE_8__.ENDÅ(0,_angular_cdk_keycodes__WEBPACK_IMPORTED_MODULE_8__.hasModifierKey)´_angular_cdk_keycodes__WEBPACK_IMPORTED_MODULE_8__.A´_angular_cdk_keycodes__WEBPACK_IMPORTED_MODULE_8__.Z·_angular_cdk_keycodes__WEBPACK_IMPORTED_MODULE_8__.ZERO·_angular_cdk_keycodes__WEBPACK_IMPORTED_MODULE_8__.NINEïç»_angular_cdk_platform__WEBPACK_IMPORTED_MODULE_9__.Platformèéêÿµ(0,rxjs_operators__WEBPACK_IMPORTED_MODULE_10__.take)åå±_angular_core__WEBPACK_IMPORTED_MODULE_0__.NgZoneäåæçèÿéåÍ(0,_angular_cdk_coercion__WEBPACK_IMPORTED_MODULE_11__.coerceBooleanProperty)ÿØ(0,_angular_cdk_platform__WEBPACK_IMPORTED_MODULE_9__._getFocusedElementPierceShadowDom)A   _angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµÉµdirectiveInject"]µ_angular_core__WEBPACK_IMPORTED_MODULE_0__.ElementRefşşáA   _angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµÉµdefineDirective"]D   _angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµÉµNgOnChangesFeature"]á´_angular_core__WEBPACK_IMPORTED_MODULE_0__.DirectiveüâŞ°_angular_core__WEBPACK_IMPORTED_MODULE_0__.Inputÿ¹_angular_core__WEBPACK_IMPORTED_MODULE_0__.InjectionTokenİŞßÛÛöÛÛÜÛİŞßöàÜ³_angular_core__WEBPACK_IMPORTED_MODULE_0__.Optionalßş¶_angular_cdk_keycodes__WEBPACK_IMPORTED_MODULE_8__.ALTº_angular_cdk_keycodes__WEBPACK_IMPORTED_MODULE_8__.CONTROL»_angular_cdk_keycodes__WEBPACK_IMPORTED_MODULE_8__.MAC_META·_angular_cdk_keycodes__WEBPACK_IMPORTED_MODULE_8__.META¸_angular_cdk_keycodes__WEBPACK_IMPORTED_MODULE_8__.SHIFTÖ(0,_angular_cdk_platform__WEBPACK_IMPORTED_MODULE_9__.normalizePassiveListenerOptions)²rxjs__WEBPACK_IMPORTED_MODULE_12__.BehaviorSubjectÆ(0,_angular_cdk_platform__WEBPACK_IMPORTED_MODULE_9__._getEventTarget)ÿÿµ(0,rxjs_operators__WEBPACK_IMPORTED_MODULE_13__.skip)Å(0,rxjs_operators__WEBPACK_IMPORTED_MODULE_14__.distinctUntilChanged)ĞéĞëĞÑĞÒÓÔéëÕÑõÕôôĞĞëĞÑĞÒÓÔõÕëÕÑõÕîïîîÄ_angular_cdk_observers__WEBPACK_IMPORTED_MODULE_15__.ContentObserveríêïÒñîÿêòóúÕüÅ(0,_angular_cdk_coercion__WEBPACK_IMPORTED_MODULE_11__.coerceElement)©(0,rxjs__WEBPACK_IMPORTED_MODULE_16__.of)Å(0,_angular_cdk_platform__WEBPACK_IMPORTED_MODULE_9__._getShadowRoot)Òııùº(0,rxjs_operators__WEBPACK_IMPORTED_MODULE_17__.takeUntil)ËæËäËËÌËÍÎÏæäğĞÌğĞ·_angular_core__WEBPACK_IMPORTED_MODULE_0__.EventEmitterèéèêÍìé±_angular_core__WEBPACK_IMPORTED_MODULE_0__.OutputÉâÉÊËÌÍâÎÊÉ@   _angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµÉµdefineNgModule"]@   _angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµÉµdefineInjector"]Á_angular_cdk_platform__WEBPACK_IMPORTED_MODULE_9__.PlatformModuleÄ_angular_cdk_observers__WEBPACK_IMPORTED_MODULE_15__.ObserversModuleÈ³_angular_core__WEBPACK_IMPORTED_MODULE_0__.NgModuleış€ÿÿÿ¶ __webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "A11yModule": () => (/* binding */ A11yModule),
/* harmony export */   "ActiveDescendantKeyManager": () => (/* binding */ ActiveDescendantKeyManager),
/* harmony export */   "AriaDescriber": () => (/* binding */ AriaDescriber),
/* harmony export */   "CDK_DESCRIBEDBY_HOST_ATTRIBUTE": () => (/* binding */ CDK_DESCRIBEDBY_HOST_ATTRIBUTE),
/* harmony export */   "CDK_DESCRIBEDBY_ID_PREFIX": () => (/* binding */ CDK_DESCRIBEDBY_ID_PREFIX),
/* harmony export */   "CdkAriaLive": () => (/* binding */ CdkAriaLive),
/* harmony export */   "CdkMonitorFocus": () => (/* binding */ CdkMonitorFocus),
/* harmony export */   "CdkTrapFocus": () => (/* binding */ CdkTrapFocus),
/* harmony export */   "ConfigurableFocusTrap": () => (/* binding */ ConfigurableFocusTrap),
/* harmony export */   "ConfigurableFocusTrapFactory": () => (/* binding */ ConfigurableFocusTrapFactory),
/* harmony export */   "EventListenerFocusTrapInertStrategy": () => (/* binding */ EventListenerFocusTrapInertStrategy),
/* harmony export */   "FOCUS_MONITOR_DEFAULT_OPTIONS": () => (/* binding */ FOCUS_MONITOR_DEFAULT_OPTIONS),
/* harmony export */   "FOCUS_TRAP_INERT_STRATEGY": () => (/* binding */ FOCUS_TRAP_INERT_STRATEGY),
/* harmony export */   "FocusKeyManager": () => (/* binding */ FocusKeyManager),
/* harmony export */   "FocusMonitor": () => (/* binding */ FocusMonitor),
/* harmony export */   "FocusTrap": () => (/* binding */ FocusTrap),
/* harmony export */   "FocusTrapFactory": () => (/* binding */ FocusTrapFactory),
/* harmony export */   "HighContrastModeDetector": () => (/* binding */ HighContrastModeDetector),
/* harmony export */   "INPUT_MODALITY_DETECTOR_DEFAULT_OPTIONS": () => (/* binding */ INPUT_MODALITY_DETECTOR_DEFAULT_OPTIONS),
/* harmony export */   "INPUT_MODALITY_DETECTOR_OPTIONS": () => (/* binding */ INPUT_MODALITY_DETECTOR_OPTIONS),
/* harmony export */   "InputModalityDetector": () => (/* binding */ InputModalityDetector),
/* harmony export */   "InteractivityChecker": () => (/* binding */ InteractivityChecker),
/* harmony export */   "IsFocusableConfig": () => (/* binding */ IsFocusableConfig),
/* harmony export */   "LIVE_ANNOUNCER_DEFAULT_OPTIONS": () => (/* binding */ LIVE_ANNOUNCER_DEFAULT_OPTIONS),
/* harmony export */   "LIVE_ANNOUNCER_ELEMENT_TOKEN": () => (/* binding */ LIVE_ANNOUNCER_ELEMENT_TOKEN),
/* harmony export */   "LIVE_ANNOUNCER_ELEMENT_TOKEN_FACTORY": () => (/* binding */ LIVE_ANNOUNCER_ELEMENT_TOKEN_FACTORY),
/* harmony export */   "ListKeyManager": () => (/* binding */ ListKeyManager),
/* harmony export */   "LiveAnnouncer": () => (/* binding */ LiveAnnouncer),
/* harmony export */   "MESSAGES_CONTAINER_ID": () => (/* binding */ MESSAGES_CONTAINER_ID),
/* harmony export */   "isFakeMousedownFromScreenReader": () => (/* binding */ isFakeMousedownFromScreenReader),
/* harmony export */   "isFakeTouchstartFromScreenReader": () => (/* binding */ isFakeTouchstartFromScreenReader)
/* harmony export */ });
/* harmony import */ var _angular_common__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! @angular/common */ 8267);
/* harmony import */ var _angular_core__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! @angular/core */ 4001);
/* harmony import */ var rxjs__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! rxjs */ 4575);
/* harmony import */ var rxjs__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! rxjs */ 1620);
/* harmony import */ var rxjs__WEBPACK_IMPORTED_MODULE_12__ = __webpack_require__(/*! rxjs */ 8824);
/* harmony import */ var rxjs__WEBPACK_IMPORTED_MODULE_16__ = __webpack_require__(/*! rxjs */ 8433);
/* harmony import */ var _angular_cdk_keycodes__WEBPACK_IMPORTED_MODULE_8__ = __webpack_require__(/*! @angular/cdk/keycodes */ 7926);
/* harmony import */ var rxjs_operators__WEBPACK_IMPORTED_MODULE_4__ = __webpack_require__(/*! rxjs/operators */ 5309);
/* harmony import */ var rxjs_operators__WEBPACK_IMPORTED_MODULE_5__ = __webpack_require__(/*! rxjs/operators */ 1082);
/* harmony import */ var rxjs_operators__WEBPACK_IMPORTED_MODULE_6__ = __webpack_require__(/*! rxjs/operators */ 1569);
/* harmony import */ var rxjs_operators__WEBPACK_IMPORTED_MODULE_7__ = __webpack_require__(/*! rxjs/operators */ 2014);
/* harmony import */ var rxjs_operators__WEBPACK_IMPORTED_MODULE_10__ = __webpack_require__(/*! rxjs/operators */ 7529);
/* harmony import */ var rxjs_operators__WEBPACK_IMPORTED_MODULE_13__ = __webpack_require__(/*! rxjs/operators */ 3295);
/* harmony import */ var rxjs_operators__WEBPACK_IMPORTED_MODULE_14__ = __webpack_require__(/*! rxjs/operators */ 1607);
/* harmony import */ var rxjs_operators__WEBPACK_IMPORTED_MODULE_17__ = __webpack_require__(/*! rxjs/operators */ 6567);
/* harmony import */ var _angular_cdk_coercion__WEBPACK_IMPORTED_MODULE_11__ = __webpack_require__(/*! @angular/cdk/coercion */ 2270);
/* harmony import */ var _angular_cdk_platform__WEBPACK_IMPORTED_MODULE_9__ = __webpack_require__(/*! @angular/cdk/platform */ 573);
/* harmony import */ var _angular_cdk_observers__WEBPACK_IMPORTED_MODULE_15__ = __webpack_require__(/*! @angular/cdk/observers */ 4095);











/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

/** IDs are delimited by an empty space, as per the spec. */

const ID_DELIMITER = ' ';
/**
 * Adds the given ID to the specified ARIA attribute on an element.
 * Used for attributes such as aria-labelledby, aria-owns, etc.
 */

function addAriaReferencedId(el, attr, id) {
  const ids = getAriaReferenceIds(el, attr);

  if (ids.some(existingId => existingId.trim() == id.trim())) {
    return;
  }

  ids.push(id.trim());
  el.setAttribute(attr, ids.join(ID_DELIMITER));
}
/**
 * Removes the given ID from the specified ARIA attribute on an element.
 * Used for attributes such as aria-labelledby, aria-owns, etc.
 */


function removeAriaReferencedId(el, attr, id) {
  const ids = getAriaReferenceIds(el, attr);
  const filteredIds = ids.filter(val => val != id.trim());

  if (filteredIds.length) {
    el.setAttribute(attr, filteredIds.join(ID_DELIMITER));
  } else {
    el.removeAttribute(attr);
  }
}
/**
 * Gets the list of IDs referenced by the given ARIA attribute on an element.
 * Used for attributes such as aria-labelledby, aria-owns, etc.
 */


function getAriaReferenceIds(el, attr) {
  // Get string array of all individual ids (whitespace delimited) in the attribute value
  return (el.getAttribute(attr) || '').match(/\S+/g) || [];
}
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

/** ID used for the body container where all messages are appended. */


const MESSAGES_CONTAINER_ID = 'cdk-describedby-message-container';
/** ID prefix used for each created message element. */

const CDK_DESCRIBEDBY_ID_PREFIX = 'cdk-describedby-message';
/** Attribute given to each host element that is described by a message element. */

const CDK_DESCRIBEDBY_HOST_ATTRIBUTE = 'cdk-describedby-host';
/** Global incremental identifier for each registered message element. */

let nextId = 0;
/** Global map of all registered message elements that have been placed into the document. */

const messageRegistry = new Map();
/** Container for all registered messages. */

let messagesContainer = null;
/**
 * Utility that creates visually hidden elements with a message content. Useful for elements that
 * want to use aria-describedby to further describe themselves without adding additional visual
 * content.
 */

class AriaDescriber {
  constructor(_document) {
    this._document = _document;
  }

  describe(hostElement, message, role) {
    if (!this._canBeDescribed(hostElement, message)) {
      return;
    }

    const key = getKey(message, role);

    if (typeof message !== 'string') {
      // We need to ensure that the element has an ID.
      setMessageId(message);
      messageRegistry.set(key, {
        messageElement: message,
        referenceCount: 0
      });
    } else if (!messageRegistry.has(key)) {
      this._createMessageElement(message, role);
    }

    if (!this._isElementDescribedByMessage(hostElement, key)) {
      this._addMessageReference(hostElement, key);
    }
  }

  removeDescription(hostElement, message, role) {
    if (!message || !this._isElementNode(hostElement)) {
      return;
    }

    const key = getKey(message, role);

    if (this._isElementDescribedByMessage(hostElement, key)) {
      this._removeMessageReference(hostElement, key);
    } // If the message is a string, it means that it's one that we created for the
    // consumer so we can remove it safely, otherwise we should leave it in place.


    if (typeof message === 'string') {
      const registeredMessage = messageRegistry.get(key);

      if (registeredMessage && registeredMessage.referenceCount === 0) {
        this._deleteMessageElement(key);
      }
    }

    if (messagesContainer && messagesContainer.childNodes.length === 0) {
      this._deleteMessagesContainer();
    }
  }
  /** Unregisters all created message elements and removes the message container. */


  ngOnDestroy() {
    const describedElements = this._document.querySelectorAll(`[${CDK_DESCRIBEDBY_HOST_ATTRIBUTE}]`);

    for (let i = 0; i < describedElements.length; i++) {
      this._removeCdkDescribedByReferenceIds(describedElements[i]);

      describedElements[i].removeAttribute(CDK_DESCRIBEDBY_HOST_ATTRIBUTE);
    }

    if (messagesContainer) {
      this._deleteMessagesContainer();
    }

    messageRegistry.clear();
  }
  /**
   * Creates a new element in the visually hidden message container element with the message
   * as its content and adds it to the message registry.
   */


  _createMessageElement(message, role) {
    const messageElement = this._document.createElement('div');

    setMessageId(messageElement);
    messageElement.textContent = message;

    if (role) {
      messageElement.setAttribute('role', role);
    }

    this._createMessagesContainer();

    messagesContainer.appendChild(messageElement);
    messageRegistry.set(getKey(message, role), {
      messageElement,
      referenceCount: 0
    });
  }
  /** Deletes the message element from the global messages container. */


  _deleteMessageElement(key) {
    const registeredMessage = messageRegistry.get(key);
    registeredMessage?.messageElement?.remove();
    messageRegistry.delete(key);
  }
  /** Creates the global container for all aria-describedby messages. */


  _createMessagesContainer() {
    if (!messagesContainer) {
      const preExistingContainer = this._document.getElementById(MESSAGES_CONTAINER_ID); // When going from the server to the client, we may end up in a situation where there's
      // already a container on the page, but we don't have a reference to it. Clear the
      // old container so we don't get duplicates. Doing this, instead of emptying the previous
      // container, should be slightly faster.


      preExistingContainer?.remove();
      messagesContainer = this._document.createElement('div');
      messagesContainer.id = MESSAGES_CONTAINER_ID; // We add `visibility: hidden` in order to prevent text in this container from
      // being searchable by the browser's Ctrl + F functionality.
      // Screen-readers will still read the description for elements with aria-describedby even
      // when the description element is not visible.

      messagesContainer.style.visibility = 'hidden'; // Even though we use `visibility: hidden`, we still apply `cdk-visually-hidden` so that
      // the description element doesn't impact page layout.

      messagesContainer.classList.add('cdk-visually-hidden');

      this._document.body.appendChild(messagesContainer);
    }
  }
  /** Deletes the global messages container. */


  _deleteMessagesContainer() {
    if (messagesContainer) {
      messagesContainer.remove();
      messagesContainer = null;
    }
  }
  /** Removes all cdk-describedby messages that are hosted through the element. */


  _removeCdkDescribedByReferenceIds(element) {
    // Remove all aria-describedby reference IDs that are prefixed by CDK_DESCRIBEDBY_ID_PREFIX
    const originalReferenceIds = getAriaReferenceIds(element, 'aria-describedby').filter(id => id.indexOf(CDK_DESCRIBEDBY_ID_PREFIX) != 0);
    element.setAttribute('aria-describedby', originalReferenceIds.join(' '));
  }
  /**
   * Adds a message reference to the element using aria-describedby and increments the registered
   * message's reference count.
   */


  _addMessageReference(element, key) {
    const registeredMessage = messageRegistry.get(key); // Add the aria-describedby reference and set the
    // describedby_host attribute to mark the element.

    addAriaReferencedId(element, 'aria-describedby', registeredMessage.messageElement.id);
    element.setAttribute(CDK_DESCRIBEDBY_HOST_ATTRIBUTE, '');
    registeredMessage.referenceCount++;
  }
  /**
   * Removes a message reference from the element using aria-describedby
   * and decrements the registered message's reference count.
   */


  _removeMessageReference(element, key) {
    const registeredMessage = messageRegistry.get(key);
    registeredMessage.referenceCount--;
    removeAriaReferencedId(element, 'aria-describedby', registeredMessage.messageElement.id);
    element.removeAttribute(CDK_DESCRIBEDBY_HOST_ATTRIBUTE);
  }
  /** Returns true if the element has been described by the provided message ID. */


  _isElementDescribedByMessage(element, key) {
    const referenceIds = getAriaReferenceIds(element, 'aria-describedby');
    const registeredMessage = messageRegistry.get(key);
    const messageId = registeredMessage && registeredMessage.messageElement.id;
    return !!messageId && referenceIds.indexOf(messageId) != -1;
  }
  /** Determines whether a message can be described on a particular element. */


  _canBeDescribed(element, message) {
    if (!this._isElementNode(element)) {
      return false;
    }

    if (message && typeof message === 'object') {
      // We'd have to make some assumptions about the description element's text, if the consumer
      // passed in an element. Assume that if an element is passed in, the consumer has verified
      // that it can be used as a description.
      return true;
    }

    const trimmedMessage = message == null ? '' : `${message}`.trim();
    const ariaLabel = element.getAttribute('aria-label'); // We shouldn't set descriptions if they're exactly the same as the `aria-label` of the
    // element, because screen readers will end up reading out the same text twice in a row.

    return trimmedMessage ? !ariaLabel || ariaLabel.trim() !== trimmedMessage : false;
  }
  /** Checks whether a node is an Element node. */


  _isElementNode(element) {
    return element.nodeType === this._document.ELEMENT_NODE;
  }

}

AriaDescriber.Éµfac = function AriaDescriber_Factory(t) {
  return new (t || AriaDescriber)(_angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµÉµinject"](_angular_common__WEBPACK_IMPORTED_MODULE_1__.DOCUMENT));
};

AriaDescriber.Éµprov = /* @__PURE__ */_angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµÉµdefineInjectable"]({
  token: AriaDescriber,
  factory: AriaDescriber.Éµfac,
  providedIn: 'root'
});

(function () {
  (typeof ngDevMode === "undefined" || ngDevMode) && _angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµsetClassMetadata"](AriaDescriber, [{
    type: _angular_core__WEBPACK_IMPORTED_MODULE_0__.Injectable,
    args: [{
      providedIn: 'root'
    }]
  }], function () {
    return [{
      type: undefined,
      decorators: [{
        type: _angular_core__WEBPACK_IMPORTED_MODULE_0__.Inject,
        args: [_angular_common__WEBPACK_IMPORTED_MODULE_1__.DOCUMENT]
      }]
    }];
  }, null);
})();
/** Gets a key that can be used to look messages up in the registry. */


function getKey(message, role) {
  return typeof message === 'string' ? `${role || ''}/${message}` : message;
}
/** Assigns a unique ID to an element, if it doesn't have one already. */


function setMessageId(element) {
  if (!element.id) {
    element.id = `${CDK_DESCRIBEDBY_ID_PREFIX}-${nextId++}`;
  }
}
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

/**
 * This class manages keyboard events for selectable lists. If you pass it a query list
 * of items, it will set the active item correctly when arrow events occur.
 */


class ListKeyManager {
  constructor(_items) {
    this._items = _items;
    this._activeItemIndex = -1;
    this._activeItem = null;
    this._wrap = false;
    this._letterKeyStream = new rxjs__WEBPACK_IMPORTED_MODULE_2__.Subject();
    this._typeaheadSubscription = rxjs__WEBPACK_IMPORTED_MODULE_3__.Subscription.EMPTY;
    this._vertical = true;
    this._allowedModifierKeys = [];
    this._homeAndEnd = false;
    /**
     * Predicate function that can be used to check whether an item should be skipped
     * by the key manager. By default, disabled items are skipped.
     */

    this._skipPredicateFn = item => item.disabled; // Buffer for the letters that the user has pressed when the typeahead option is turned on.


    this._pressedLetters = [];
    /**
     * Stream that emits any time the TAB key is pressed, so components can react
     * when focus is shifted off of the list.
     */

    this.tabOut = new rxjs__WEBPACK_IMPORTED_MODULE_2__.Subject();
    /** Stream that emits whenever the active item of the list manager changes. */

    this.change = new rxjs__WEBPACK_IMPORTED_MODULE_2__.Subject(); // We allow for the items to be an array because, in some cases, the consumer may
    // not have access to a QueryList of the items they want to manage (e.g. when the
    // items aren't being collected via `ViewChildren` or `ContentChildren`).

    if (_items instanceof _angular_core__WEBPACK_IMPORTED_MODULE_0__.QueryList) {
      _items.changes.subscribe(newItems => {
        if (this._activeItem) {
          const itemArray = newItems.toArray();
          const newIndex = itemArray.indexOf(this._activeItem);

          if (newIndex > -1 && newIndex !== this._activeItemIndex) {
            this._activeItemIndex = newIndex;
          }
        }
      });
    }
  }
  /**
   * Sets the predicate function that determines which items should be skipped by the
   * list key manager.
   * @param predicate Function that determines whether the given item should be skipped.
   */


  skipPredicate(predicate) {
    this._skipPredicateFn = predicate;
    return this;
  }
  /**
   * Configures wrapping mode, which determines whether the active item will wrap to
   * the other end of list when there are no more items in the given direction.
   * @param shouldWrap Whether the list should wrap when reaching the end.
   */


  withWrap(shouldWrap = true) {
    this._wrap = shouldWrap;
    return this;
  }
  /**
   * Configures whether the key manager should be able to move the selection vertically.
   * @param enabled Whether vertical selection should be enabled.
   */


  withVerticalOrientation(enabled = true) {
    this._vertical = enabled;
    return this;
  }
  /**
   * Configures the key manager to move the selection horizontally.
   * Passing in `null` will disable horizontal movement.
   * @param direction Direction in which the selection can be moved.
   */


  withHorizontalOrientation(direction) {
    this._horizontal = direction;
    return this;
  }
  /**
   * Modifier keys which are allowed to be held down and whose default actions will be prevented
   * as the user is pressing the arrow keys. Defaults to not allowing any modifier keys.
   */


  withAllowedModifierKeys(keys) {
    this._allowedModifierKeys = keys;
    return this;
  }
  /**
   * Turns on typeahead mode which allows users to set the active item by typing.
   * @param debounceInterval Time to wait after the last keystroke before setting the active item.
   */


  withTypeAhead(debounceInterval = 200) {
    if ((typeof ngDevMode === 'undefined' || ngDevMode) && this._items.length && this._items.some(item => typeof item.getLabel !== 'function')) {
      throw Error('ListKeyManager items in typeahead mode must implement the `getLabel` method.');
    }

    this._typeaheadSubscription.unsubscribe(); // Debounce the presses of non-navigational keys, collect the ones that correspond to letters
    // and convert those letters back into a string. Afterwards find the first item that starts
    // with that string and select it.


    this._typeaheadSubscription = this._letterKeyStream.pipe((0,rxjs_operators__WEBPACK_IMPORTED_MODULE_4__.tap)(letter => this._pressedLetters.push(letter)), (0,rxjs_operators__WEBPACK_IMPORTED_MODULE_5__.debounceTime)(debounceInterval), (0,rxjs_operators__WEBPACK_IMPORTED_MODULE_6__.filter)(() => this._pressedLetters.length > 0), (0,rxjs_operators__WEBPACK_IMPORTED_MODULE_7__.map)(() => this._pressedLetters.join(''))).subscribe(inputString => {
      const items = this._getItemsArray(); // Start at 1 because we want to start searching at the item immediately
      // following the current active item.


      for (let i = 1; i < items.length + 1; i++) {
        const index = (this._activeItemIndex + i) % items.length;
        const item = items[index];

        if (!this._skipPredicateFn(item) && item.getLabel().toUpperCase().trim().indexOf(inputString) === 0) {
          this.setActiveItem(index);
          break;
        }
      }

      this._pressedLetters = [];
    });
    return this;
  }
  /**
   * Configures the key manager to activate the first and last items
   * respectively when the Home or End key is pressed.
   * @param enabled Whether pressing the Home or End key activates the first/last item.
   */


  withHomeAndEnd(enabled = true) {
    this._homeAndEnd = enabled;
    return this;
  }

  setActiveItem(item) {
    const previousActiveItem = this._activeItem;
    this.updateActiveItem(item);

    if (this._activeItem !== previousActiveItem) {
      this.change.next(this._activeItemIndex);
    }
  }
  /**
   * Sets the active item depending on the key event passed in.
   * @param event Keyboard event to be used for determining which element should be active.
   */


  onKeydown(event) {
    const keyCode = event.keyCode;
    const modifiers = ['altKey', 'ctrlKey', 'metaKey', 'shiftKey'];
    const isModifierAllowed = modifiers.every(modifier => {
      return !event[modifier] || this._allowedModifierKeys.indexOf(modifier) > -1;
    });

    switch (keyCode) {
      case _angular_cdk_keycodes__WEBPACK_IMPORTED_MODULE_8__.TAB:
        this.tabOut.next();
        return;

      case _angular_cdk_keycodes__WEBPACK_IMPORTED_MODULE_8__.DOWN_ARROW:
        if (this._vertical && isModifierAllowed) {
          this.setNextItemActive();
          break;
        } else {
          return;
        }

      case _angular_cdk_keycodes__WEBPACK_IMPORTED_MODULE_8__.UP_ARROW:
        if (this._vertical && isModifierAllowed) {
          this.setPreviousItemActive();
          break;
        } else {
          return;
        }

      case _angular_cdk_keycodes__WEBPACK_IMPORTED_MODULE_8__.RIGHT_ARROW:
        if (this._horizontal && isModifierAllowed) {
          this._horizontal === 'rtl' ? this.setPreviousItemActive() : this.setNextItemActive();
          break;
        } else {
          return;
        }

      case _angular_cdk_keycodes__WEBPACK_IMPORTED_MODULE_8__.LEFT_ARROW:
        if (this._horizontal && isModifierAllowed) {
          this._horizontal === 'rtl' ? this.setNextItemActive() : this.setPreviousItemActive();
          break;
        } else {
          return;
        }

      case _angular_cdk_keycodes__WEBPACK_IMPORTED_MODULE_8__.HOME:
        if (this._homeAndEnd && isModifierAllowed) {
          this.setFirstItemActive();
          break;
        } else {
          return;
        }

      case _angular_cdk_keycodes__WEBPACK_IMPORTED_MODULE_8__.END:
        if (this._homeAndEnd && isModifierAllowed) {
          this.setLastItemActive();
          break;
        } else {
          return;
        }

      default:
        if (isModifierAllowed || (0,_angular_cdk_keycodes__WEBPACK_IMPORTED_MODULE_8__.hasModifierKey)(event, 'shiftKey')) {
          // Attempt to use the `event.key` which also maps it to the user's keyboard language,
          // otherwise fall back to resolving alphanumeric characters via the keyCode.
          if (event.key && event.key.length === 1) {
            this._letterKeyStream.next(event.key.toLocaleUpperCase());
          } else if (keyCode >= _angular_cdk_keycodes__WEBPACK_IMPORTED_MODULE_8__.A && keyCode <= _angular_cdk_keycodes__WEBPACK_IMPORTED_MODULE_8__.Z || keyCode >= _angular_cdk_keycodes__WEBPACK_IMPORTED_MODULE_8__.ZERO && keyCode <= _angular_cdk_keycodes__WEBPACK_IMPORTED_MODULE_8__.NINE) {
            this._letterKeyStream.next(String.fromCharCode(keyCode));
          }
        } // Note that we return here, in order to avoid preventing
        // the default action of non-navigational keys.


        return;
    }

    this._pressedLetters = [];
    event.preventDefault();
  }
  /** Index of the currently active item. */


  get activeItemIndex() {
    return this._activeItemIndex;
  }
  /** The active item. */


  get activeItem() {
    return this._activeItem;
  }
  /** Gets whether the user is currently typing into the manager using the typeahead feature. */


  isTyping() {
    return this._pressedLetters.length > 0;
  }
  /** Sets the active item to the first enabled item in the list. */


  setFirstItemActive() {
    this._setActiveItemByIndex(0, 1);
  }
  /** Sets the active item to the last enabled item in the list. */


  setLastItemActive() {
    this._setActiveItemByIndex(this._items.length - 1, -1);
  }
  /** Sets the active item to the next enabled item in the list. */


  setNextItemActive() {
    this._activeItemIndex < 0 ? this.setFirstItemActive() : this._setActiveItemByDelta(1);
  }
  /** Sets the active item to a previous enabled item in the list. */


  setPreviousItemActive() {
    this._activeItemIndex < 0 && this._wrap ? this.setLastItemActive() : this._setActiveItemByDelta(-1);
  }

  updateActiveItem(item) {
    const itemArray = this._getItemsArray();

    const index = typeof item === 'number' ? item : itemArray.indexOf(item);
    const activeItem = itemArray[index]; // Explicitly check for `null` and `undefined` because other falsy values are valid.

    this._activeItem = activeItem == null ? null : activeItem;
    this._activeItemIndex = index;
  }
  /**
   * This method sets the active item, given a list of items and the delta between the
   * currently active item and the new active item. It will calculate differently
   * depending on whether wrap mode is turned on.
   */


  _setActiveItemByDelta(delta) {
    this._wrap ? this._setActiveInWrapMode(delta) : this._setActiveInDefaultMode(delta);
  }
  /**
   * Sets the active item properly given "wrap" mode. In other words, it will continue to move
   * down the list until it finds an item that is not disabled, and it will wrap if it
   * encounters either end of the list.
   */


  _setActiveInWrapMode(delta) {
    const items = this._getItemsArray();

    for (let i = 1; i <= items.length; i++) {
      const index = (this._activeItemIndex + delta * i + items.length) % items.length;
      const item = items[index];

      if (!this._skipPredicateFn(item)) {
        this.setActiveItem(index);
        return;
      }
    }
  }
  /**
   * Sets the active item properly given the default mode. In other words, it will
   * continue to move down the list until it finds an item that is not disabled. If
   * it encounters either end of the list, it will stop and not wrap.
   */


  _setActiveInDefaultMode(delta) {
    this._setActiveItemByIndex(this._activeItemIndex + delta, delta);
  }
  /**
   * Sets the active item to the first enabled item starting at the index specified. If the
   * item is disabled, it will move in the fallbackDelta direction until it either
   * finds an enabled item or encounters the end of the list.
   */


  _setActiveItemByIndex(index, fallbackDelta) {
    const items = this._getItemsArray();

    if (!items[index]) {
      return;
    }

    while (this._skipPredicateFn(items[index])) {
      index += fallbackDelta;

      if (!items[index]) {
        return;
      }
    }

    this.setActiveItem(index);
  }
  /** Returns the items as an array. */


  _getItemsArray() {
    return this._items instanceof _angular_core__WEBPACK_IMPORTED_MODULE_0__.QueryList ? this._items.toArray() : this._items;
  }

}
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */


class ActiveDescendantKeyManager extends ListKeyManager {
  setActiveItem(index) {
    if (this.activeItem) {
      this.activeItem.setInactiveStyles();
    }

    super.setActiveItem(index);

    if (this.activeItem) {
      this.activeItem.setActiveStyles();
    }
  }

}
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */


class FocusKeyManager extends ListKeyManager {
  constructor() {
    super(...arguments);
    this._origin = 'program';
  }
  /**
   * Sets the focus origin that will be passed in to the items for any subsequent `focus` calls.
   * @param origin Focus origin to be used when focusing items.
   */


  setFocusOrigin(origin) {
    this._origin = origin;
    return this;
  }

  setActiveItem(item) {
    super.setActiveItem(item);

    if (this.activeItem) {
      this.activeItem.focus(this._origin);
    }
  }

}
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

/**
 * Configuration for the isFocusable method.
 */


class IsFocusableConfig {
  constructor() {
    /**
     * Whether to count an element as focusable even if it is not currently visible.
     */
    this.ignoreVisibility = false;
  }

} // The InteractivityChecker leans heavily on the ally.js accessibility utilities.
// Methods like `isTabbable` are only covering specific edge-cases for the browsers which are
// supported.

/**
 * Utility for checking the interactivity of an element, such as whether is is focusable or
 * tabbable.
 */


class InteractivityChecker {
  constructor(_platform) {
    this._platform = _platform;
  }
  /**
   * Gets whether an element is disabled.
   *
   * @param element Element to be checked.
   * @returns Whether the element is disabled.
   */


  isDisabled(element) {
    // This does not capture some cases, such as a non-form control with a disabled attribute or
    // a form control inside of a disabled form, but should capture the most common cases.
    return element.hasAttribute('disabled');
  }
  /**
   * Gets whether an element is visible for the purposes of interactivity.
   *
   * This will capture states like `display: none` and `visibility: hidden`, but not things like
   * being clipped by an `overflow: hidden` parent or being outside the viewport.
   *
   * @returns Whether the element is visible.
   */


  isVisible(element) {
    return hasGeometry(element) && getComputedStyle(element).visibility === 'visible';
  }
  /**
   * Gets whether an element can be reached via Tab key.
   * Assumes that the element has already been checked with isFocusable.
   *
   * @param element Element to be checked.
   * @returns Whether the element is tabbable.
   */


  isTabbable(element) {
    // Nothing is tabbable on the server ğŸ˜
    if (!this._platform.isBrowser) {
      return false;
    }

    const frameElement = getFrameElement(getWindow(element));

    if (frameElement) {
      // Frame elements inherit their tabindex onto all child elements.
      if (getTabIndexValue(frameElement) === -1) {
        return false;
      } // Browsers disable tabbing to an element inside of an invisible frame.


      if (!this.isVisible(frameElement)) {
        return false;
      }
    }

    let nodeName = element.nodeName.toLowerCase();
    let tabIndexValue = getTabIndexValue(element);

    if (element.hasAttribute('contenteditable')) {
      return tabIndexValue !== -1;
    }

    if (nodeName === 'iframe' || nodeName === 'object') {
      // The frame or object's content may be tabbable depending on the content, but it's
      // not possibly to reliably detect the content of the frames. We always consider such
      // elements as non-tabbable.
      return false;
    } // In iOS, the browser only considers some specific elements as tabbable.


    if (this._platform.WEBKIT && this._platform.IOS && !isPotentiallyTabbableIOS(element)) {
      return false;
    }

    if (nodeName === 'audio') {
      // Audio elements without controls enabled are never tabbable, regardless
      // of the tabindex attribute explicitly being set.
      if (!element.hasAttribute('controls')) {
        return false;
      } // Audio elements with controls are by default tabbable unless the
      // tabindex attribute is set to `-1` explicitly.


      return tabIndexValue !== -1;
    }

    if (nodeName === 'video') {
      // For all video elements, if the tabindex attribute is set to `-1`, the video
      // is not tabbable. Note: We cannot rely on the default `HTMLElement.tabIndex`
      // property as that one is set to `-1` in Chrome, Edge and Safari v13.1. The
      // tabindex attribute is the source of truth here.
      if (tabIndexValue === -1) {
        return false;
      } // If the tabindex is explicitly set, and not `-1` (as per check before), the
      // video element is always tabbable (regardless of whether it has controls or not).


      if (tabIndexValue !== null) {
        return true;
      } // Otherwise (when no explicit tabindex is set), a video is only tabbable if it
      // has controls enabled. Firefox is special as videos are always tabbable regardless
      // of whether there are controls or not.


      return this._platform.FIREFOX || element.hasAttribute('controls');
    }

    return element.tabIndex >= 0;
  }
  /**
   * Gets whether an element can be focused by the user.
   *
   * @param element Element to be checked.
   * @param config The config object with options to customize this method's behavior
   * @returns Whether the element is focusable.
   */


  isFocusable(element, config) {
    // Perform checks in order of left to most expensive.
    // Again, naive approach that does not capture many edge cases and browser quirks.
    return isPotentiallyFocusable(element) && !this.isDisabled(element) && (config?.ignoreVisibility || this.isVisible(element));
  }

}

InteractivityChecker.Éµfac = function InteractivityChecker_Factory(t) {
  return new (t || InteractivityChecker)(_angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµÉµinject"](_angular_cdk_platform__WEBPACK_IMPORTED_MODULE_9__.Platform));
};

InteractivityChecker.Éµprov = /* @__PURE__ */_angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµÉµdefineInjectable"]({
  token: InteractivityChecker,
  factory: InteractivityChecker.Éµfac,
  providedIn: 'root'
});

(function () {
  (typeof ngDevMode === "undefined" || ngDevMode) && _angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµsetClassMetadata"](InteractivityChecker, [{
    type: _angular_core__WEBPACK_IMPORTED_MODULE_0__.Injectable,
    args: [{
      providedIn: 'root'
    }]
  }], function () {
    return [{
      type: _angular_cdk_platform__WEBPACK_IMPORTED_MODULE_9__.Platform
    }];
  }, null);
})();
/**
 * Returns the frame element from a window object. Since browsers like MS Edge throw errors if
 * the frameElement property is being accessed from a different host address, this property
 * should be accessed carefully.
 */


function getFrameElement(window) {
  try {
    return window.frameElement;
  } catch {
    return null;
  }
}
/** Checks whether the specified element has any geometry / rectangles. */


function hasGeometry(element) {
  // Use logic from jQuery to check for an invisible element.
  // See https://github.com/jquery/jquery/blob/master/src/css/hiddenVisibleSelectors.js#L12
  return !!(element.offsetWidth || element.offsetHeight || typeof element.getClientRects === 'function' && element.getClientRects().length);
}
/** Gets whether an element's  */


function isNativeFormElement(element) {
  let nodeName = element.nodeName.toLowerCase();
  return nodeName === 'input' || nodeName === 'select' || nodeName === 'button' || nodeName === 'textarea';
}
/** Gets whether an element is an `<input type="hidden">`. */


function isHiddenInput(element) {
  return isInputElement(element) && element.type == 'hidden';
}
/** Gets whether an element is an anchor that has an href attribute. */


function isAnchorWithHref(element) {
  return isAnchorElement(element) && element.hasAttribute('href');
}
/** Gets whether an element is an input element. */


function isInputElement(element) {
  return element.nodeName.toLowerCase() == 'input';
}
/** Gets whether an element is an anchor element. */


function isAnchorElement(element) {
  return element.nodeName.toLowerCase() == 'a';
}
/** Gets whether an element has a valid tabindex. */


function hasValidTabIndex(element) {
  if (!element.hasAttribute('tabindex') || element.tabIndex === undefined) {
    return false;
  }

  let tabIndex = element.getAttribute('tabindex');
  return !!(tabIndex && !isNaN(parseInt(tabIndex, 10)));
}
/**
 * Returns the parsed tabindex from the element attributes instead of returning the
 * evaluated tabindex from the browsers defaults.
 */


function getTabIndexValue(element) {
  if (!hasValidTabIndex(element)) {
    return null;
  } // See browser issue in Gecko https://bugzilla.mozilla.org/show_bug.cgi?id=1128054


  const tabIndex = parseInt(element.getAttribute('tabindex') || '', 10);
  return isNaN(tabIndex) ? -1 : tabIndex;
}
/** Checks whether the specified element is potentially tabbable on iOS */


function isPotentiallyTabbableIOS(element) {
  let nodeName = element.nodeName.toLowerCase();
  let inputType = nodeName === 'input' && element.type;
  return inputType === 'text' || inputType === 'password' || nodeName === 'select' || nodeName === 'textarea';
}
/**
 * Gets whether an element is potentially focusable without taking current visible/disabled state
 * into account.
 */


function isPotentiallyFocusable(element) {
  // Inputs are potentially focusable *unless* they're type="hidden".
  if (isHiddenInput(element)) {
    return false;
  }

  return isNativeFormElement(element) || isAnchorWithHref(element) || element.hasAttribute('contenteditable') || hasValidTabIndex(element);
}
/** Gets the parent window of a DOM node with regards of being inside of an iframe. */


function getWindow(node) {
  // ownerDocument is null if `node` itself *is* a document.
  return node.ownerDocument && node.ownerDocument.defaultView || window;
}
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

/**
 * Class that allows for trapping focus within a DOM element.
 *
 * This class currently uses a relatively simple approach to focus trapping.
 * It assumes that the tab order is the same as DOM order, which is not necessarily true.
 * Things like `tabIndex > 0`, flex `order`, and shadow roots can cause the two to be misaligned.
 *
 * @deprecated Use `ConfigurableFocusTrap` instead.
 * @breaking-change 11.0.0
 */


class FocusTrap {
  constructor(_element, _checker, _ngZone, _document, deferAnchors = false) {
    this._element = _element;
    this._checker = _checker;
    this._ngZone = _ngZone;
    this._document = _document;
    this._hasAttached = false; // Event listeners for the anchors. Need to be regular functions so that we can unbind them later.

    this.startAnchorListener = () => this.focusLastTabbableElement();

    this.endAnchorListener = () => this.focusFirstTabbableElement();

    this._enabled = true;

    if (!deferAnchors) {
      this.attachAnchors();
    }
  }
  /** Whether the focus trap is active. */


  get enabled() {
    return this._enabled;
  }

  set enabled(value) {
    this._enabled = value;

    if (this._startAnchor && this._endAnchor) {
      this._toggleAnchorTabIndex(value, this._startAnchor);

      this._toggleAnchorTabIndex(value, this._endAnchor);
    }
  }
  /** Destroys the focus trap by cleaning up the anchors. */


  destroy() {
    const startAnchor = this._startAnchor;
    const endAnchor = this._endAnchor;

    if (startAnchor) {
      startAnchor.removeEventListener('focus', this.startAnchorListener);
      startAnchor.remove();
    }

    if (endAnchor) {
      endAnchor.removeEventListener('focus', this.endAnchorListener);
      endAnchor.remove();
    }

    this._startAnchor = this._endAnchor = null;
    this._hasAttached = false;
  }
  /**
   * Inserts the anchors into the DOM. This is usually done automatically
   * in the constructor, but can be deferred for cases like directives with `*ngIf`.
   * @returns Whether the focus trap managed to attach successfully. This may not be the case
   * if the target element isn't currently in the DOM.
   */


  attachAnchors() {
    // If we're not on the browser, there can be no focus to trap.
    if (this._hasAttached) {
      return true;
    }

    this._ngZone.runOutsideAngular(() => {
      if (!this._startAnchor) {
        this._startAnchor = this._createAnchor();

        this._startAnchor.addEventListener('focus', this.startAnchorListener);
      }

      if (!this._endAnchor) {
        this._endAnchor = this._createAnchor();

        this._endAnchor.addEventListener('focus', this.endAnchorListener);
      }
    });

    if (this._element.parentNode) {
      this._element.parentNode.insertBefore(this._startAnchor, this._element);

      this._element.parentNode.insertBefore(this._endAnchor, this._element.nextSibling);

      this._hasAttached = true;
    }

    return this._hasAttached;
  }
  /**
   * Waits for the zone to stabilize, then focuses the first tabbable element.
   * @returns Returns a promise that resolves with a boolean, depending
   * on whether focus was moved successfully.
   */


  focusInitialElementWhenReady(options) {
    return new Promise(resolve => {
      this._executeOnStable(() => resolve(this.focusInitialElement(options)));
    });
  }
  /**
   * Waits for the zone to stabilize, then focuses
   * the first tabbable element within the focus trap region.
   * @returns Returns a promise that resolves with a boolean, depending
   * on whether focus was moved successfully.
   */


  focusFirstTabbableElementWhenReady(options) {
    return new Promise(resolve => {
      this._executeOnStable(() => resolve(this.focusFirstTabbableElement(options)));
    });
  }
  /**
   * Waits for the zone to stabilize, then focuses
   * the last tabbable element within the focus trap region.
   * @returns Returns a promise that resolves with a boolean, depending
   * on whether focus was moved successfully.
   */


  focusLastTabbableElementWhenReady(options) {
    return new Promise(resolve => {
      this._executeOnStable(() => resolve(this.focusLastTabbableElement(options)));
    });
  }
  /**
   * Get the specified boundary element of the trapped region.
   * @param bound The boundary to get (start or end of trapped region).
   * @returns The boundary element.
   */


  _getRegionBoundary(bound) {
    // Contains the deprecated version of selector, for temporary backwards comparability.
    let markers = this._element.querySelectorAll(`[cdk-focus-region-${bound}], ` + `[cdkFocusRegion${bound}], ` + `[cdk-focus-${bound}]`);

    for (let i = 0; i < markers.length; i++) {
      // @breaking-change 8.0.0
      if (markers[i].hasAttribute(`cdk-focus-${bound}`)) {
        console.warn(`Found use of deprecated attribute 'cdk-focus-${bound}', ` + `use 'cdkFocusRegion${bound}' instead. The deprecated ` + `attribute will be removed in 8.0.0.`, markers[i]);
      } else if (markers[i].hasAttribute(`cdk-focus-region-${bound}`)) {
        console.warn(`Found use of deprecated attribute 'cdk-focus-region-${bound}', ` + `use 'cdkFocusRegion${bound}' instead. The deprecated attribute ` + `will be removed in 8.0.0.`, markers[i]);
      }
    }

    if (bound == 'start') {
      return markers.length ? markers[0] : this._getFirstTabbableElement(this._element);
    }

    return markers.length ? markers[markers.length - 1] : this._getLastTabbableElement(this._element);
  }
  /**
   * Focuses the element that should be focused when the focus trap is initialized.
   * @returns Whether focus was moved successfully.
   */


  focusInitialElement(options) {
    // Contains the deprecated version of selector, for temporary backwards comparability.
    const redirectToElement = this._element.querySelector(`[cdk-focus-initial], ` + `[cdkFocusInitial]`);

    if (redirectToElement) {
      // @breaking-change 8.0.0
      if (redirectToElement.hasAttribute(`cdk-focus-initial`)) {
        console.warn(`Found use of deprecated attribute 'cdk-focus-initial', ` + `use 'cdkFocusInitial' instead. The deprecated attribute ` + `will be removed in 8.0.0`, redirectToElement);
      } // Warn the consumer if the element they've pointed to
      // isn't focusable, when not in production mode.


      if ((typeof ngDevMode === 'undefined' || ngDevMode) && !this._checker.isFocusable(redirectToElement)) {
        console.warn(`Element matching '[cdkFocusInitial]' is not focusable.`, redirectToElement);
      }

      if (!this._checker.isFocusable(redirectToElement)) {
        const focusableChild = this._getFirstTabbableElement(redirectToElement);

        focusableChild?.focus(options);
        return !!focusableChild;
      }

      redirectToElement.focus(options);
      return true;
    }

    return this.focusFirstTabbableElement(options);
  }
  /**
   * Focuses the first tabbable element within the focus trap region.
   * @returns Whether focus was moved successfully.
   */


  focusFirstTabbableElement(options) {
    const redirectToElement = this._getRegionBoundary('start');

    if (redirectToElement) {
      redirectToElement.focus(options);
    }

    return !!redirectToElement;
  }
  /**
   * Focuses the last tabbable element within the focus trap region.
   * @returns Whether focus was moved successfully.
   */


  focusLastTabbableElement(options) {
    const redirectToElement = this._getRegionBoundary('end');

    if (redirectToElement) {
      redirectToElement.focus(options);
    }

    return !!redirectToElement;
  }
  /**
   * Checks whether the focus trap has successfully been attached.
   */


  hasAttached() {
    return this._hasAttached;
  }
  /** Get the first tabbable element from a DOM subtree (inclusive). */


  _getFirstTabbableElement(root) {
    if (this._checker.isFocusable(root) && this._checker.isTabbable(root)) {
      return root;
    }

    const children = root.children;

    for (let i = 0; i < children.length; i++) {
      const tabbableChild = children[i].nodeType === this._document.ELEMENT_NODE ? this._getFirstTabbableElement(children[i]) : null;

      if (tabbableChild) {
        return tabbableChild;
      }
    }

    return null;
  }
  /** Get the last tabbable element from a DOM subtree (inclusive). */


  _getLastTabbableElement(root) {
    if (this._checker.isFocusable(root) && this._checker.isTabbable(root)) {
      return root;
    } // Iterate in reverse DOM order.


    const children = root.children;

    for (let i = children.length - 1; i >= 0; i--) {
      const tabbableChild = children[i].nodeType === this._document.ELEMENT_NODE ? this._getLastTabbableElement(children[i]) : null;

      if (tabbableChild) {
        return tabbableChild;
      }
    }

    return null;
  }
  /** Creates an anchor element. */


  _createAnchor() {
    const anchor = this._document.createElement('div');

    this._toggleAnchorTabIndex(this._enabled, anchor);

    anchor.classList.add('cdk-visually-hidden');
    anchor.classList.add('cdk-focus-trap-anchor');
    anchor.setAttribute('aria-hidden', 'true');
    return anchor;
  }
  /**
   * Toggles the `tabindex` of an anchor, based on the enabled state of the focus trap.
   * @param isEnabled Whether the focus trap is enabled.
   * @param anchor Anchor on which to toggle the tabindex.
   */


  _toggleAnchorTabIndex(isEnabled, anchor) {
    // Remove the tabindex completely, rather than setting it to -1, because if the
    // element has a tabindex, the user might still hit it when navigating with the arrow keys.
    isEnabled ? anchor.setAttribute('tabindex', '0') : anchor.removeAttribute('tabindex');
  }
  /**
   * Toggles the`tabindex` of both anchors to either trap Tab focus or allow it to escape.
   * @param enabled: Whether the anchors should trap Tab.
   */


  toggleAnchors(enabled) {
    if (this._startAnchor && this._endAnchor) {
      this._toggleAnchorTabIndex(enabled, this._startAnchor);

      this._toggleAnchorTabIndex(enabled, this._endAnchor);
    }
  }
  /** Executes a function when the zone is stable. */


  _executeOnStable(fn) {
    if (this._ngZone.isStable) {
      fn();
    } else {
      this._ngZone.onStable.pipe((0,rxjs_operators__WEBPACK_IMPORTED_MODULE_10__.take)(1)).subscribe(fn);
    }
  }

}
/**
 * Factory that allows easy instantiation of focus traps.
 * @deprecated Use `ConfigurableFocusTrapFactory` instead.
 * @breaking-change 11.0.0
 */


class FocusTrapFactory {
  constructor(_checker, _ngZone, _document) {
    this._checker = _checker;
    this._ngZone = _ngZone;
    this._document = _document;
  }
  /**
   * Creates a focus-trapped region around the given element.
   * @param element The element around which focus will be trapped.
   * @param deferCaptureElements Defers the creation of focus-capturing elements to be done
   *     manually by the user.
   * @returns The created focus trap instance.
   */


  create(element, deferCaptureElements = false) {
    return new FocusTrap(element, this._checker, this._ngZone, this._document, deferCaptureElements);
  }

}

FocusTrapFactory.Éµfac = function FocusTrapFactory_Factory(t) {
  return new (t || FocusTrapFactory)(_angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµÉµinject"](InteractivityChecker), _angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµÉµinject"](_angular_core__WEBPACK_IMPORTED_MODULE_0__.NgZone), _angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµÉµinject"](_angular_common__WEBPACK_IMPORTED_MODULE_1__.DOCUMENT));
};

FocusTrapFactory.Éµprov = /* @__PURE__ */_angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµÉµdefineInjectable"]({
  token: FocusTrapFactory,
  factory: FocusTrapFactory.Éµfac,
  providedIn: 'root'
});

(function () {
  (typeof ngDevMode === "undefined" || ngDevMode) && _angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµsetClassMetadata"](FocusTrapFactory, [{
    type: _angular_core__WEBPACK_IMPORTED_MODULE_0__.Injectable,
    args: [{
      providedIn: 'root'
    }]
  }], function () {
    return [{
      type: InteractivityChecker
    }, {
      type: _angular_core__WEBPACK_IMPORTED_MODULE_0__.NgZone
    }, {
      type: undefined,
      decorators: [{
        type: _angular_core__WEBPACK_IMPORTED_MODULE_0__.Inject,
        args: [_angular_common__WEBPACK_IMPORTED_MODULE_1__.DOCUMENT]
      }]
    }];
  }, null);
})();
/** Directive for trapping focus within a region. */


class CdkTrapFocus {
  constructor(_elementRef, _focusTrapFactory,
  /**
   * @deprecated No longer being used. To be removed.
   * @breaking-change 13.0.0
   */
  _document) {
    this._elementRef = _elementRef;
    this._focusTrapFactory = _focusTrapFactory;
    /** Previously focused element to restore focus to upon destroy when using autoCapture. */

    this._previouslyFocusedElement = null;
    this.focusTrap = this._focusTrapFactory.create(this._elementRef.nativeElement, true);
  }
  /** Whether the focus trap is active. */


  get enabled() {
    return this.focusTrap.enabled;
  }

  set enabled(value) {
    this.focusTrap.enabled = (0,_angular_cdk_coercion__WEBPACK_IMPORTED_MODULE_11__.coerceBooleanProperty)(value);
  }
  /**
   * Whether the directive should automatically move focus into the trapped region upon
   * initialization and return focus to the previous activeElement upon destruction.
   */


  get autoCapture() {
    return this._autoCapture;
  }

  set autoCapture(value) {
    this._autoCapture = (0,_angular_cdk_coercion__WEBPACK_IMPORTED_MODULE_11__.coerceBooleanProperty)(value);
  }

  ngOnDestroy() {
    this.focusTrap.destroy(); // If we stored a previously focused element when using autoCapture, return focus to that
    // element now that the trapped region is being destroyed.

    if (this._previouslyFocusedElement) {
      this._previouslyFocusedElement.focus();

      this._previouslyFocusedElement = null;
    }
  }

  ngAfterContentInit() {
    this.focusTrap.attachAnchors();

    if (this.autoCapture) {
      this._captureFocus();
    }
  }

  ngDoCheck() {
    if (!this.focusTrap.hasAttached()) {
      this.focusTrap.attachAnchors();
    }
  }

  ngOnChanges(changes) {
    const autoCaptureChange = changes['autoCapture'];

    if (autoCaptureChange && !autoCaptureChange.firstChange && this.autoCapture && this.focusTrap.hasAttached()) {
      this._captureFocus();
    }
  }

  _captureFocus() {
    this._previouslyFocusedElement = (0,_angular_cdk_platform__WEBPACK_IMPORTED_MODULE_9__._getFocusedElementPierceShadowDom)();
    this.focusTrap.focusInitialElementWhenReady();
  }

}

CdkTrapFocus.Éµfac = function CdkTrapFocus_Factory(t) {
  return new (t || CdkTrapFocus)(_angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµÉµdirectiveInject"](_angular_core__WEBPACK_IMPORTED_MODULE_0__.ElementRef), _angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµÉµdirectiveInject"](FocusTrapFactory), _angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµÉµdirectiveInject"](_angular_common__WEBPACK_IMPORTED_MODULE_1__.DOCUMENT));
};

CdkTrapFocus.Éµdir = /* @__PURE__ */_angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµÉµdefineDirective"]({
  type: CdkTrapFocus,
  selectors: [["", "cdkTrapFocus", ""]],
  inputs: {
    enabled: ["cdkTrapFocus", "enabled"],
    autoCapture: ["cdkTrapFocusAutoCapture", "autoCapture"]
  },
  exportAs: ["cdkTrapFocus"],
  features: [_angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµÉµNgOnChangesFeature"]]
});

(function () {
  (typeof ngDevMode === "undefined" || ngDevMode) && _angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµsetClassMetadata"](CdkTrapFocus, [{
    type: _angular_core__WEBPACK_IMPORTED_MODULE_0__.Directive,
    args: [{
      selector: '[cdkTrapFocus]',
      exportAs: 'cdkTrapFocus'
    }]
  }], function () {
    return [{
      type: _angular_core__WEBPACK_IMPORTED_MODULE_0__.ElementRef
    }, {
      type: FocusTrapFactory
    }, {
      type: undefined,
      decorators: [{
        type: _angular_core__WEBPACK_IMPORTED_MODULE_0__.Inject,
        args: [_angular_common__WEBPACK_IMPORTED_MODULE_1__.DOCUMENT]
      }]
    }];
  }, {
    enabled: [{
      type: _angular_core__WEBPACK_IMPORTED_MODULE_0__.Input,
      args: ['cdkTrapFocus']
    }],
    autoCapture: [{
      type: _angular_core__WEBPACK_IMPORTED_MODULE_0__.Input,
      args: ['cdkTrapFocusAutoCapture']
    }]
  });
})();
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

/**
 * Class that allows for trapping focus within a DOM element.
 *
 * This class uses a strategy pattern that determines how it traps focus.
 * See FocusTrapInertStrategy.
 */


class ConfigurableFocusTrap extends FocusTrap {
  constructor(_element, _checker, _ngZone, _document, _focusTrapManager, _inertStrategy, config) {
    super(_element, _checker, _ngZone, _document, config.defer);
    this._focusTrapManager = _focusTrapManager;
    this._inertStrategy = _inertStrategy;

    this._focusTrapManager.register(this);
  }
  /** Whether the FocusTrap is enabled. */


  get enabled() {
    return this._enabled;
  }

  set enabled(value) {
    this._enabled = value;

    if (this._enabled) {
      this._focusTrapManager.register(this);
    } else {
      this._focusTrapManager.deregister(this);
    }
  }
  /** Notifies the FocusTrapManager that this FocusTrap will be destroyed. */


  destroy() {
    this._focusTrapManager.deregister(this);

    super.destroy();
  }
  /** @docs-private Implemented as part of ManagedFocusTrap. */


  _enable() {
    this._inertStrategy.preventFocus(this);

    this.toggleAnchors(true);
  }
  /** @docs-private Implemented as part of ManagedFocusTrap. */


  _disable() {
    this._inertStrategy.allowFocus(this);

    this.toggleAnchors(false);
  }

}
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

/** The injection token used to specify the inert strategy. */


const FOCUS_TRAP_INERT_STRATEGY = new _angular_core__WEBPACK_IMPORTED_MODULE_0__.InjectionToken('FOCUS_TRAP_INERT_STRATEGY');
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

/**
 * Lightweight FocusTrapInertStrategy that adds a document focus event
 * listener to redirect focus back inside the FocusTrap.
 */

class EventListenerFocusTrapInertStrategy {
  constructor() {
    /** Focus event handler. */
    this._listener = null;
  }
  /** Adds a document event listener that keeps focus inside the FocusTrap. */


  preventFocus(focusTrap) {
    // Ensure there's only one listener per document
    if (this._listener) {
      focusTrap._document.removeEventListener('focus', this._listener, true);
    }

    this._listener = e => this._trapFocus(focusTrap, e);

    focusTrap._ngZone.runOutsideAngular(() => {
      focusTrap._document.addEventListener('focus', this._listener, true);
    });
  }
  /** Removes the event listener added in preventFocus. */


  allowFocus(focusTrap) {
    if (!this._listener) {
      return;
    }

    focusTrap._document.removeEventListener('focus', this._listener, true);

    this._listener = null;
  }
  /**
   * Refocuses the first element in the FocusTrap if the focus event target was outside
   * the FocusTrap.
   *
   * This is an event listener callback. The event listener is added in runOutsideAngular,
   * so all this code runs outside Angular as well.
   */


  _trapFocus(focusTrap, event) {
    const target = event.target;
    const focusTrapRoot = focusTrap._element; // Don't refocus if target was in an overlay, because the overlay might be associated
    // with an element inside the FocusTrap, ex. mat-select.

    if (target && !focusTrapRoot.contains(target) && !target.closest?.('div.cdk-overlay-pane')) {
      // Some legacy FocusTrap usages have logic that focuses some element on the page
      // just before FocusTrap is destroyed. For backwards compatibility, wait
      // to be sure FocusTrap is still enabled before refocusing.
      setTimeout(() => {
        // Check whether focus wasn't put back into the focus trap while the timeout was pending.
        if (focusTrap.enabled && !focusTrapRoot.contains(focusTrap._document.activeElement)) {
          focusTrap.focusFirstTabbableElement();
        }
      });
    }
  }

}
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

/** Injectable that ensures only the most recently enabled FocusTrap is active. */


class FocusTrapManager {
  constructor() {
    // A stack of the FocusTraps on the page. Only the FocusTrap at the
    // top of the stack is active.
    this._focusTrapStack = [];
  }
  /**
   * Disables the FocusTrap at the top of the stack, and then pushes
   * the new FocusTrap onto the stack.
   */


  register(focusTrap) {
    // Dedupe focusTraps that register multiple times.
    this._focusTrapStack = this._focusTrapStack.filter(ft => ft !== focusTrap);
    let stack = this._focusTrapStack;

    if (stack.length) {
      stack[stack.length - 1]._disable();
    }

    stack.push(focusTrap);

    focusTrap._enable();
  }
  /**
   * Removes the FocusTrap from the stack, and activates the
   * FocusTrap that is the new top of the stack.
   */


  deregister(focusTrap) {
    focusTrap._disable();

    const stack = this._focusTrapStack;
    const i = stack.indexOf(focusTrap);

    if (i !== -1) {
      stack.splice(i, 1);

      if (stack.length) {
        stack[stack.length - 1]._enable();
      }
    }
  }

}

FocusTrapManager.Éµfac = function FocusTrapManager_Factory(t) {
  return new (t || FocusTrapManager)();
};

FocusTrapManager.Éµprov = /* @__PURE__ */_angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµÉµdefineInjectable"]({
  token: FocusTrapManager,
  factory: FocusTrapManager.Éµfac,
  providedIn: 'root'
});

(function () {
  (typeof ngDevMode === "undefined" || ngDevMode) && _angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµsetClassMetadata"](FocusTrapManager, [{
    type: _angular_core__WEBPACK_IMPORTED_MODULE_0__.Injectable,
    args: [{
      providedIn: 'root'
    }]
  }], null, null);
})();
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

/** Factory that allows easy instantiation of configurable focus traps. */


class ConfigurableFocusTrapFactory {
  constructor(_checker, _ngZone, _focusTrapManager, _document, _inertStrategy) {
    this._checker = _checker;
    this._ngZone = _ngZone;
    this._focusTrapManager = _focusTrapManager;
    this._document = _document; // TODO split up the strategies into different modules, similar to DateAdapter.

    this._inertStrategy = _inertStrategy || new EventListenerFocusTrapInertStrategy();
  }

  create(element, config = {
    defer: false
  }) {
    let configObject;

    if (typeof config === 'boolean') {
      configObject = {
        defer: config
      };
    } else {
      configObject = config;
    }

    return new ConfigurableFocusTrap(element, this._checker, this._ngZone, this._document, this._focusTrapManager, this._inertStrategy, configObject);
  }

}

ConfigurableFocusTrapFactory.Éµfac = function ConfigurableFocusTrapFactory_Factory(t) {
  return new (t || ConfigurableFocusTrapFactory)(_angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµÉµinject"](InteractivityChecker), _angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµÉµinject"](_angular_core__WEBPACK_IMPORTED_MODULE_0__.NgZone), _angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµÉµinject"](FocusTrapManager), _angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµÉµinject"](_angular_common__WEBPACK_IMPORTED_MODULE_1__.DOCUMENT), _angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµÉµinject"](FOCUS_TRAP_INERT_STRATEGY, 8));
};

ConfigurableFocusTrapFactory.Éµprov = /* @__PURE__ */_angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµÉµdefineInjectable"]({
  token: ConfigurableFocusTrapFactory,
  factory: ConfigurableFocusTrapFactory.Éµfac,
  providedIn: 'root'
});

(function () {
  (typeof ngDevMode === "undefined" || ngDevMode) && _angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµsetClassMetadata"](ConfigurableFocusTrapFactory, [{
    type: _angular_core__WEBPACK_IMPORTED_MODULE_0__.Injectable,
    args: [{
      providedIn: 'root'
    }]
  }], function () {
    return [{
      type: InteractivityChecker
    }, {
      type: _angular_core__WEBPACK_IMPORTED_MODULE_0__.NgZone
    }, {
      type: FocusTrapManager
    }, {
      type: undefined,
      decorators: [{
        type: _angular_core__WEBPACK_IMPORTED_MODULE_0__.Inject,
        args: [_angular_common__WEBPACK_IMPORTED_MODULE_1__.DOCUMENT]
      }]
    }, {
      type: undefined,
      decorators: [{
        type: _angular_core__WEBPACK_IMPORTED_MODULE_0__.Optional
      }, {
        type: _angular_core__WEBPACK_IMPORTED_MODULE_0__.Inject,
        args: [FOCUS_TRAP_INERT_STRATEGY]
      }]
    }];
  }, null);
})();
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

/** Gets whether an event could be a faked `mousedown` event dispatched by a screen reader. */


function isFakeMousedownFromScreenReader(event) {
  // Some screen readers will dispatch a fake `mousedown` event when pressing enter or space on
  // a clickable element. We can distinguish these events when both `offsetX` and `offsetY` are
  // zero. Note that there's an edge case where the user could click the 0x0 spot of the screen
  // themselves, but that is unlikely to contain interaction elements. Historically we used to
  // check `event.buttons === 0`, however that no longer works on recent versions of NVDA.
  return event.offsetX === 0 && event.offsetY === 0;
}
/** Gets whether an event could be a faked `touchstart` event dispatched by a screen reader. */


function isFakeTouchstartFromScreenReader(event) {
  const touch = event.touches && event.touches[0] || event.changedTouches && event.changedTouches[0]; // A fake `touchstart` can be distinguished from a real one by looking at the `identifier`
  // which is typically >= 0 on a real device versus -1 from a screen reader. Just to be safe,
  // we can also look at `radiusX` and `radiusY`. This behavior was observed against a Windows 10
  // device with a touch screen running NVDA v2020.4 and Firefox 85 or Chrome 88.

  return !!touch && touch.identifier === -1 && (touch.radiusX == null || touch.radiusX === 1) && (touch.radiusY == null || touch.radiusY === 1);
}
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

/**
 * Injectable options for the InputModalityDetector. These are shallowly merged with the default
 * options.
 */


const INPUT_MODALITY_DETECTOR_OPTIONS = new _angular_core__WEBPACK_IMPORTED_MODULE_0__.InjectionToken('cdk-input-modality-detector-options');
/**
 * Default options for the InputModalityDetector.
 *
 * Modifier keys are ignored by default (i.e. when pressed won't cause the service to detect
 * keyboard input modality) for two reasons:
 *
 * 1. Modifier keys are commonly used with mouse to perform actions such as 'right click' or 'open
 *    in new tab', and are thus less representative of actual keyboard interaction.
 * 2. VoiceOver triggers some keyboard events when linearly navigating with Control + Option (but
 *    confusingly not with Caps Lock). Thus, to have parity with other screen readers, we ignore
 *    these keys so as to not update the input modality.
 *
 * Note that we do not by default ignore the right Meta key on Safari because it has the same key
 * code as the ContextMenu key on other browsers. When we switch to using event.key, we can
 * distinguish between the two.
 */

const INPUT_MODALITY_DETECTOR_DEFAULT_OPTIONS = {
  ignoreKeys: [_angular_cdk_keycodes__WEBPACK_IMPORTED_MODULE_8__.ALT, _angular_cdk_keycodes__WEBPACK_IMPORTED_MODULE_8__.CONTROL, _angular_cdk_keycodes__WEBPACK_IMPORTED_MODULE_8__.MAC_META, _angular_cdk_keycodes__WEBPACK_IMPORTED_MODULE_8__.META, _angular_cdk_keycodes__WEBPACK_IMPORTED_MODULE_8__.SHIFT]
};
/**
 * The amount of time needed to pass after a touchstart event in order for a subsequent mousedown
 * event to be attributed as mouse and not touch.
 *
 * This is the value used by AngularJS Material. Through trial and error (on iPhone 6S) they found
 * that a value of around 650ms seems appropriate.
 */

const TOUCH_BUFFER_MS = 650;
/**
 * Event listener options that enable capturing and also mark the listener as passive if the browser
 * supports it.
 */

const modalityEventListenerOptions = (0,_angular_cdk_platform__WEBPACK_IMPORTED_MODULE_9__.normalizePassiveListenerOptions)({
  passive: true,
  capture: true
});
/**
 * Service that detects the user's input modality.
 *
 * This service does not update the input modality when a user navigates with a screen reader
 * (e.g. linear navigation with VoiceOver, object navigation / browse mode with NVDA, virtual PC
 * cursor mode with JAWS). This is in part due to technical limitations (i.e. keyboard events do not
 * fire as expected in these modes) but is also arguably the correct behavior. Navigating with a
 * screen reader is akin to visually scanning a page, and should not be interpreted as actual user
 * input interaction.
 *
 * When a user is not navigating but *interacting* with a screen reader, this service attempts to
 * update the input modality to keyboard, but in general this service's behavior is largely
 * undefined.
 */

class InputModalityDetector {
  constructor(_platform, ngZone, document, options) {
    this._platform = _platform;
    /**
     * The most recently detected input modality event target. Is null if no input modality has been
     * detected or if the associated event target is null for some unknown reason.
     */

    this._mostRecentTarget = null;
    /** The underlying BehaviorSubject that emits whenever an input modality is detected. */

    this._modality = new rxjs__WEBPACK_IMPORTED_MODULE_12__.BehaviorSubject(null);
    /**
     * The timestamp of the last touch input modality. Used to determine whether mousedown events
     * should be attributed to mouse or touch.
     */

    this._lastTouchMs = 0;
    /**
     * Handles keydown events. Must be an arrow function in order to preserve the context when it gets
     * bound.
     */

    this._onKeydown = event => {
      // If this is one of the keys we should ignore, then ignore it and don't update the input
      // modality to keyboard.
      if (this._options?.ignoreKeys?.some(keyCode => keyCode === event.keyCode)) {
        return;
      }

      this._modality.next('keyboard');

      this._mostRecentTarget = (0,_angular_cdk_platform__WEBPACK_IMPORTED_MODULE_9__._getEventTarget)(event);
    };
    /**
     * Handles mousedown events. Must be an arrow function in order to preserve the context when it
     * gets bound.
     */


    this._onMousedown = event => {
      // Touches trigger both touch and mouse events, so we need to distinguish between mouse events
      // that were triggered via mouse vs touch. To do so, check if the mouse event occurs closely
      // after the previous touch event.
      if (Date.now() - this._lastTouchMs < TOUCH_BUFFER_MS) {
        return;
      } // Fake mousedown events are fired by some screen readers when controls are activated by the
      // screen reader. Attribute them to keyboard input modality.


      this._modality.next(isFakeMousedownFromScreenReader(event) ? 'keyboard' : 'mouse');

      this._mostRecentTarget = (0,_angular_cdk_platform__WEBPACK_IMPORTED_MODULE_9__._getEventTarget)(event);
    };
    /**
     * Handles touchstart events. Must be an arrow function in order to preserve the context when it
     * gets bound.
     */


    this._onTouchstart = event => {
      // Same scenario as mentioned in _onMousedown, but on touch screen devices, fake touchstart
      // events are fired. Again, attribute to keyboard input modality.
      if (isFakeTouchstartFromScreenReader(event)) {
        this._modality.next('keyboard');

        return;
      } // Store the timestamp of this touch event, as it's used to distinguish between mouse events
      // triggered via mouse vs touch.


      this._lastTouchMs = Date.now();

      this._modality.next('touch');

      this._mostRecentTarget = (0,_angular_cdk_platform__WEBPACK_IMPORTED_MODULE_9__._getEventTarget)(event);
    };

    this._options = { ...INPUT_MODALITY_DETECTOR_DEFAULT_OPTIONS,
      ...options
    }; // Skip the first emission as it's null.

    this.modalityDetected = this._modality.pipe((0,rxjs_operators__WEBPACK_IMPORTED_MODULE_13__.skip)(1));
    this.modalityChanged = this.modalityDetected.pipe((0,rxjs_operators__WEBPACK_IMPORTED_MODULE_14__.distinctUntilChanged)()); // If we're not in a browser, this service should do nothing, as there's no relevant input
    // modality to detect.

    if (_platform.isBrowser) {
      ngZone.runOutsideAngular(() => {
        document.addEventListener('keydown', this._onKeydown, modalityEventListenerOptions);
        document.addEventListener('mousedown', this._onMousedown, modalityEventListenerOptions);
        document.addEventListener('touchstart', this._onTouchstart, modalityEventListenerOptions);
      });
    }
  }
  /** The most recently detected input modality. */


  get mostRecentModality() {
    return this._modality.value;
  }

  ngOnDestroy() {
    this._modality.complete();

    if (this._platform.isBrowser) {
      document.removeEventListener('keydown', this._onKeydown, modalityEventListenerOptions);
      document.removeEventListener('mousedown', this._onMousedown, modalityEventListenerOptions);
      document.removeEventListener('touchstart', this._onTouchstart, modalityEventListenerOptions);
    }
  }

}

InputModalityDetector.Éµfac = function InputModalityDetector_Factory(t) {
  return new (t || InputModalityDetector)(_angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµÉµinject"](_angular_cdk_platform__WEBPACK_IMPORTED_MODULE_9__.Platform), _angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµÉµinject"](_angular_core__WEBPACK_IMPORTED_MODULE_0__.NgZone), _angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµÉµinject"](_angular_common__WEBPACK_IMPORTED_MODULE_1__.DOCUMENT), _angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµÉµinject"](INPUT_MODALITY_DETECTOR_OPTIONS, 8));
};

InputModalityDetector.Éµprov = /* @__PURE__ */_angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµÉµdefineInjectable"]({
  token: InputModalityDetector,
  factory: InputModalityDetector.Éµfac,
  providedIn: 'root'
});

(function () {
  (typeof ngDevMode === "undefined" || ngDevMode) && _angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµsetClassMetadata"](InputModalityDetector, [{
    type: _angular_core__WEBPACK_IMPORTED_MODULE_0__.Injectable,
    args: [{
      providedIn: 'root'
    }]
  }], function () {
    return [{
      type: _angular_cdk_platform__WEBPACK_IMPORTED_MODULE_9__.Platform
    }, {
      type: _angular_core__WEBPACK_IMPORTED_MODULE_0__.NgZone
    }, {
      type: Document,
      decorators: [{
        type: _angular_core__WEBPACK_IMPORTED_MODULE_0__.Inject,
        args: [_angular_common__WEBPACK_IMPORTED_MODULE_1__.DOCUMENT]
      }]
    }, {
      type: undefined,
      decorators: [{
        type: _angular_core__WEBPACK_IMPORTED_MODULE_0__.Optional
      }, {
        type: _angular_core__WEBPACK_IMPORTED_MODULE_0__.Inject,
        args: [INPUT_MODALITY_DETECTOR_OPTIONS]
      }]
    }];
  }, null);
})();
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */


const LIVE_ANNOUNCER_ELEMENT_TOKEN = new _angular_core__WEBPACK_IMPORTED_MODULE_0__.InjectionToken('liveAnnouncerElement', {
  providedIn: 'root',
  factory: LIVE_ANNOUNCER_ELEMENT_TOKEN_FACTORY
});
/** @docs-private */

function LIVE_ANNOUNCER_ELEMENT_TOKEN_FACTORY() {
  return null;
}
/** Injection token that can be used to configure the default options for the LiveAnnouncer. */


const LIVE_ANNOUNCER_DEFAULT_OPTIONS = new _angular_core__WEBPACK_IMPORTED_MODULE_0__.InjectionToken('LIVE_ANNOUNCER_DEFAULT_OPTIONS');
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

class LiveAnnouncer {
  constructor(elementToken, _ngZone, _document, _defaultOptions) {
    this._ngZone = _ngZone;
    this._defaultOptions = _defaultOptions; // We inject the live element and document as `any` because the constructor signature cannot
    // reference browser globals (HTMLElement, Document) on non-browser environments, since having
    // a class decorator causes TypeScript to preserve the constructor signature types.

    this._document = _document;
    this._liveElement = elementToken || this._createLiveElement();
  }

  announce(message, ...args) {
    const defaultOptions = this._defaultOptions;
    let politeness;
    let duration;

    if (args.length === 1 && typeof args[0] === 'number') {
      duration = args[0];
    } else {
      [politeness, duration] = args;
    }

    this.clear();
    clearTimeout(this._previousTimeout);

    if (!politeness) {
      politeness = defaultOptions && defaultOptions.politeness ? defaultOptions.politeness : 'polite';
    }

    if (duration == null && defaultOptions) {
      duration = defaultOptions.duration;
    } // TODO: ensure changing the politeness works on all environments we support.


    this._liveElement.setAttribute('aria-live', politeness); // This 100ms timeout is necessary for some browser + screen-reader combinations:
    // - Both JAWS and NVDA over IE11 will not announce anything without a non-zero timeout.
    // - With Chrome and IE11 with NVDA or JAWS, a repeated (identical) message won't be read a
    //   second time without clearing and then using a non-zero delay.
    // (using JAWS 17 at time of this writing).


    return this._ngZone.runOutsideAngular(() => {
      return new Promise(resolve => {
        clearTimeout(this._previousTimeout);
        this._previousTimeout = setTimeout(() => {
          this._liveElement.textContent = message;
          resolve();

          if (typeof duration === 'number') {
            this._previousTimeout = setTimeout(() => this.clear(), duration);
          }
        }, 100);
      });
    });
  }
  /**
   * Clears the current text from the announcer element. Can be used to prevent
   * screen readers from reading the text out again while the user is going
   * through the page landmarks.
   */


  clear() {
    if (this._liveElement) {
      this._liveElement.textContent = '';
    }
  }

  ngOnDestroy() {
    clearTimeout(this._previousTimeout);
    this._liveElement?.remove();
    this._liveElement = null;
  }

  _createLiveElement() {
    const elementClass = 'cdk-live-announcer-element';

    const previousElements = this._document.getElementsByClassName(elementClass);

    const liveEl = this._document.createElement('div'); // Remove any old containers. This can happen when coming in from a server-side-rendered page.


    for (let i = 0; i < previousElements.length; i++) {
      previousElements[i].remove();
    }

    liveEl.classList.add(elementClass);
    liveEl.classList.add('cdk-visually-hidden');
    liveEl.setAttribute('aria-atomic', 'true');
    liveEl.setAttribute('aria-live', 'polite');

    this._document.body.appendChild(liveEl);

    return liveEl;
  }

}

LiveAnnouncer.Éµfac = function LiveAnnouncer_Factory(t) {
  return new (t || LiveAnnouncer)(_angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµÉµinject"](LIVE_ANNOUNCER_ELEMENT_TOKEN, 8), _angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµÉµinject"](_angular_core__WEBPACK_IMPORTED_MODULE_0__.NgZone), _angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµÉµinject"](_angular_common__WEBPACK_IMPORTED_MODULE_1__.DOCUMENT), _angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµÉµinject"](LIVE_ANNOUNCER_DEFAULT_OPTIONS, 8));
};

LiveAnnouncer.Éµprov = /* @__PURE__ */_angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµÉµdefineInjectable"]({
  token: LiveAnnouncer,
  factory: LiveAnnouncer.Éµfac,
  providedIn: 'root'
});

(function () {
  (typeof ngDevMode === "undefined" || ngDevMode) && _angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµsetClassMetadata"](LiveAnnouncer, [{
    type: _angular_core__WEBPACK_IMPORTED_MODULE_0__.Injectable,
    args: [{
      providedIn: 'root'
    }]
  }], function () {
    return [{
      type: undefined,
      decorators: [{
        type: _angular_core__WEBPACK_IMPORTED_MODULE_0__.Optional
      }, {
        type: _angular_core__WEBPACK_IMPORTED_MODULE_0__.Inject,
        args: [LIVE_ANNOUNCER_ELEMENT_TOKEN]
      }]
    }, {
      type: _angular_core__WEBPACK_IMPORTED_MODULE_0__.NgZone
    }, {
      type: undefined,
      decorators: [{
        type: _angular_core__WEBPACK_IMPORTED_MODULE_0__.Inject,
        args: [_angular_common__WEBPACK_IMPORTED_MODULE_1__.DOCUMENT]
      }]
    }, {
      type: undefined,
      decorators: [{
        type: _angular_core__WEBPACK_IMPORTED_MODULE_0__.Optional
      }, {
        type: _angular_core__WEBPACK_IMPORTED_MODULE_0__.Inject,
        args: [LIVE_ANNOUNCER_DEFAULT_OPTIONS]
      }]
    }];
  }, null);
})();
/**
 * A directive that works similarly to aria-live, but uses the LiveAnnouncer to ensure compatibility
 * with a wider range of browsers and screen readers.
 */


class CdkAriaLive {
  constructor(_elementRef, _liveAnnouncer, _contentObserver, _ngZone) {
    this._elementRef = _elementRef;
    this._liveAnnouncer = _liveAnnouncer;
    this._contentObserver = _contentObserver;
    this._ngZone = _ngZone;
    this._politeness = 'polite';
  }
  /** The aria-live politeness level to use when announcing messages. */


  get politeness() {
    return this._politeness;
  }

  set politeness(value) {
    this._politeness = value === 'off' || value === 'assertive' ? value : 'polite';

    if (this._politeness === 'off') {
      if (this._subscription) {
        this._subscription.unsubscribe();

        this._subscription = null;
      }
    } else if (!this._subscription) {
      this._subscription = this._ngZone.runOutsideAngular(() => {
        return this._contentObserver.observe(this._elementRef).subscribe(() => {
          // Note that we use textContent here, rather than innerText, in order to avoid a reflow.
          const elementText = this._elementRef.nativeElement.textContent; // The `MutationObserver` fires also for attribute
          // changes which we don't want to announce.

          if (elementText !== this._previousAnnouncedText) {
            this._liveAnnouncer.announce(elementText, this._politeness);

            this._previousAnnouncedText = elementText;
          }
        });
      });
    }
  }

  ngOnDestroy() {
    if (this._subscription) {
      this._subscription.unsubscribe();
    }
  }

}

CdkAriaLive.Éµfac = function CdkAriaLive_Factory(t) {
  return new (t || CdkAriaLive)(_angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµÉµdirectiveInject"](_angular_core__WEBPACK_IMPORTED_MODULE_0__.ElementRef), _angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµÉµdirectiveInject"](LiveAnnouncer), _angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµÉµdirectiveInject"](_angular_cdk_observers__WEBPACK_IMPORTED_MODULE_15__.ContentObserver), _angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµÉµdirectiveInject"](_angular_core__WEBPACK_IMPORTED_MODULE_0__.NgZone));
};

CdkAriaLive.Éµdir = /* @__PURE__ */_angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµÉµdefineDirective"]({
  type: CdkAriaLive,
  selectors: [["", "cdkAriaLive", ""]],
  inputs: {
    politeness: ["cdkAriaLive", "politeness"]
  },
  exportAs: ["cdkAriaLive"]
});

(function () {
  (typeof ngDevMode === "undefined" || ngDevMode) && _angular_core__WEBPACK_IMPORTED_MODULE_0__["ÉµsetClassMetadata"](CdkAriaLive, [{
    type: _angular_core__WEBPACK_IMPORTED_MODULE_0__.Directive,
    args: [{
      selector: '[cdkAriaLive]',
      exportAs: 'cdkAriaLive'
    }]
  }], function () {
    return [{
      type: _angular_core__WEBPACK_IMPORTED_MODULE_0__.ElementRef
    }, {
      type: LiveAnnouncer
    }, {
      type: _angular_cdk_observers__WEBPACK_IMPORTED_MODULE_15__.ContentObserver
    }, {
      type: _angular_core__WEBPACK_IMPORTED_MODULE_0__.NgZone
    }];
  }, {
    politeness: [{
      type: _angular_core__WEBPACK_IMPORTED_MODULE_0__.Input,
      args: ['cdkAriaLive']
    }]
  });
})();
/**
 * @license
 * Copyright Google LLC All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

/** InjectionToken for FocusMonitorOptions. */


const FOCUS_MONITOR_DEFAULT_OPTIONS = new _angular_core__WEBPACK_IMPORTED_MODULE_0__.InjectionToken('cdk-focus-monitor-default-options');
/**
 * Event listener options that enable capturing and also
 * mark the listener as passive if the browser supports it.
 */

const captureEventListenerOptions = (0,_angular_cdk_platform__WEBPACK_IMPORTED_MODULE_9__.normalizePassiveListenerOptions)({
  passive: true,
  capture: true
});
/** Monitors mouse and keyboard events to determine the cause of focus events. */

class FocusMonitor {
  constructor(_ngZone, _platform, _inputModalityDetector,
  /** @breaking-change 11.0.0 make document required */
  document, options) {
    this._ngZone = _ngZone;
    this._platform = _platform;
    this._inputModalityDetector = _inputModalityDetector;
    /** The focus origin that the next focus event is a result of. */

    this._origin = null;
    /** Whether the window has just been focused. */

    this._windowFocused = false;
    /**
     * Whether the origin was determined via a touch interaction. Necessary as properly attributing
     * focus events to touch interactions requires special logic.
     */

    this._originFromTouchInteraction = false;
    /** Map of elements being monitored to their info. */

    this._elementInfo = new Map();
    /** The number of elements currently being monitored. */

    this._monitoredElementCount = 0;
    /**
     * Keeps track of the root nodes to which we've currently bound a focus/blur handler,
     * as well as the number of monitored elements that they contain. We have to treat focus/blur
     * handlers differently from the rest of the events, because the browser won't emit events
     * to the document when focus moves inside of a shadow root.
     */

    this._rootNodeFocusListenerCount = new Map();
    /**
     * Event listener for `focus` events on the window.
     * Needs to be an arrow function in order to preserve the context when it gets bound.
     */

    this._windowFocusListener = () => {
      // Make a note of when the window regains focus, so we can
      // restore the origin info for the focused element.
      this._windowFocused = true;
      this._windowFocusTimeoutId = setTimeout(() => this._windowFocused = false);
    };
    /** Subject for stopping our InputModalityDetector subscription. */


    this._stopInputModalityDetector = new rxjs__WEBPACK_IMPORTED_MODULE_2__.Subject();
    /**
     * Event listener for `focus` and 'blur' events on the document.
     * Needs to be an arrow function in order to preserve the context when it gets bound.
     */

    this._rootNodeFocusAndBlurListener = event => {
      const target = (0,_angular_cdk_platform__WEBPACK_IMPORTED_MODULE_9__._getEventTarget)(event);

      const handler = event.type === 'focus' ? this._onFocus : this._onBlur; // We need to walk up the ancestor chain in order to support `checkChildren`.

      for (let element = target; element; element = element.parentElement) {
        handler.call(this, event, element);
      }
    };

    this._document = document;
    this._detectionMode = options?.detectionMode || 0
    /* IMMEDIATE */
    ;
  }

  monitor(element, checkChildren = false) {
    const nativeElement = (0,_angular_cdk_coercion__WEBPACK_IMPORTED_MODULE_11__.coerceElement)(element); // Do nothing if we're not on the browser platform or the passed in node isn't an element.

    if (!this._platform.isBrowser || nativeElement.nodeType !== 1) {
      return (0,rxjs__WEBPACK_IMPORTED_MODULE_16__.of)(null);
    } // If the element is inside the shadow DOM, we need to bind our focus/blur listeners to
    // the shadow root, rather than the `document`, because the browser won't emit focus events
    // to the `document`, if focus is moving within the same shadow root.


    const rootNode = (0,_angular_cdk_platform__WEBPACK_IMPORTED_MODULE_9__._getShadowRoot)(nativeElement) || this._getDocument();

    const cachedInfo = this._elementInfo.get(nativeElement); // Check if we're already monitoring this element.


    if (cachedInfo) {
      if (checkChildren) {
        // TODO(COMP-318): this can be problematic, because it'll turn all non-checkChildren
        // observers into ones that behave as if `checkChildren` was turned on. We need a more
        // robust solution.
        cachedInfo.checkChildren = true;
      }

      return cachedInfo.subject;
    } // Create monitored element info.


    const info = {
      checkChildren: checkChildren,
      subject: new rxjs__WEBPACK_IMPORTED_MODULE_2__.Subject(),
      rootNode
    };

    this._elementInfo.set(nativeElement, info);

    this._registerGlobalListeners(info);

    return info.subject;
  }

  stopMonitoring(element) {
    const nativeElement = (0,_angular_cdk_coercion__WEBPACK_IMPORTED_MODULE_11__.coerceElement)(element);

    const elementInfo = this._elementInfo.get(nativeElement);

    if (elementInfo) {
      elementInfo.subject.complete();

      this._setClasses(nativeElement);

      this._elementInfo.delete(nativeElement);

      this._removeGlobalListeners(elementInfo);
    }
  }

  focusVia(element, origin, options) {
    const nativeElement = (0,_angular_cdk_coercion__WEBPACK_IMPORTED_MODULE_11__.coerceElement)(element);

    const focusedElement = this._getDocument().activeElement; // If the element is focused already, calling `focus` again won't trigger the event listener
    // which means that the focus classes won't be updated. If that's the case, update the classes
    // directly without waiting for an event.


    if (nativeElement === focusedElement) {
      this._getClosestElementsInfo(nativeElement).forEach(([currentElement, info]) => this._originChanged(currentElement, origin, info));
    } else {
      this._setOrigin(origin); // `focus` isn't available on the server


      if (typeof nativeElement.focus === 'function') {
        nativeElement.focus(options);
      }
    }
  }

  ngOnDestroy() {
    this._elementInfo.forEach((_info, element) => this.stopMonitoring(element));
  }
  /** Access injected document if available or fallback to global document reference */


  _getDocument() {
    return this._document || document;
  }
  /** Use defaultView of injected document if available or fallback to global window reference */


  _getWindow() {
    const doc = this._getDocument();

    return doc.defaultView || window;
  }

  _getFocusOrigin(focusEventTarget) {
    if (this._origin) {
      // If the origin was realized via a touch interaction, we need to perform additional checks
      // to determine whether the focus origin should be attributed to touch or program.
      if (this._originFromTouchInteraction) {
        return this._shouldBeAttributedToTouch(focusEventTarget) ? 'touch' : 'program';
      } else {
        return this._origin;
      }
    } // If the window has just regained focus, we can restore the most recent origin from before the
    // window blurred. Otherwise, we've reached the point where we can't identify the source of the
    // focus. This typically means one of two things happened:
    //
    // 1) The element was programmatically focused, or
    // 2) The element was focused via screen reader navigation (which generally doesn't fire
    //    events).
    //
    // Because we can't distinguish between these two cases, we default to setting `program`.


    return this._windowFocused && this._lastFocusOrigin ? this._lastFocusOrigin : 'program';
  }
  /**
   * Returns whether the focus event should be attributed to touch. Recall that in IMMEDIATE mode, a
   * touch origin isn't immediately reset at the next tick (see _setOrigin). This means that when we
   * handle a focus event following a touch interaction, we need to determine whether (1) the focus
   * event was directly caused by the touch interaction or (2) the focus event was caused by a
   * subsequent programmatic focus call triggered by the touch interaction.
   * @param focusEventTarget The target of the focus event under examination.
   */


  _shouldBeAttributedToTouch(focusEventTarget) {
    // Please note that this check is not perfect. Consider the following edge case:
    //
    // <div #parent tabindex="0">
    //   <div #child tabindex="0" (click)="#parent.focus()"></div>
    // </div>
    //
    // Suppose there is a FocusMonitor in IMMEDIATE mode attached to #parent. When the user touches
    // #child, #parent is programmatically focused. This code will attribute the focus to touch
    // instead of program. This is a relatively minor edge-case that can be worked around by using
    // focusVia(parent, 'program') to focus #parent.
    return this._detectionMode === 1
    /* EVENTUAL */
    || !!focusEventTarget?.contains(this._inputModalityDetector._mostRecentTarget);
  }
  /**
   * Sets the focus classes on the element based on the given focus origin.
   * @param element The element to update the classes on.
   * @param origin The focus origin.
   */


  _setClasses(element, origin) {
    element.classList.toggle('cdk-focused', !!origin);
    element.classList.toggle('cdk-touch-focused', origin === 'touch');
    element.classList.toggle('cdk-keyboard-focused', origin === 'keyboard');
    element.classList.toggle('cdk-mouse-focused', origin === 'mouse');
    element.classList.toggle('cdk-program-focused', origin === 'program');
  }
  /**
   * Updates the focus origin. If we're using immediate detection mode, we schedule an async
   * function to clear the origin at the end of a timeout. The duration of the timeout depends on
   * the origin being set.
   * @param origin The origin to set.
   * @param isFromInteraction Whether we are setting the origin from an interaction event.
   */


  _setOrigin(origin, isFromInteraction = false) {
    this._ngZone.runOutsideAngular(() => {
      this._origin = origin;
      this._originFromTouchInteraction = origin === 'touch' && isFromInteraction; // If we're in IMMEDIATE mode, reset the origin at the next tick (or in `TOUCH_BUFFER_MS` ms
      // for a touch event). We reset the origin at the next tick because Firefox focuses one tick
      // after the interaction event. We wait `TOUCH_BUFFER_MS` ms before resetting the origin for
      // a touch event because when a touch event is fired, the associated focus event isn't yet in
      // the event queue. Before doing so, clear any pending timeouts.

      if (this._detectionMode === 0
      /* IMMEDIATE */
      ) {
        clearTimeout(this._originTimeoutId);
        const ms = this._originFromTouchInteraction ? TOUCH_BUFFER_MS : 1;
        this._originTimeoutId = setTimeout(() => this._origin = null, ms);
      }
    });
  }
  /**
   * Handles focus events on a registered element.
   * @param event The focus event.
   * @param element The monitored element.
   */


  _onFocus(event, element) {
    // NOTE(mmalerba): We currently set the classes based on the focus origin of the most recent
    // focus event affecting the monitored element. If we want to use the origin of the first event
    // instead we should check for the cdk-focused class here and return if the element already has
    // it. (This only matters for elements that have includesChildren = true).
    // If we are not counting child-element-focus as focused, make sure that the event target is the
    // monitored element itself.
    const elementInfo = this._elementInfo.get(element);

    const focusEventTarget = (0,_angular_cdk_platform__WEBPACK_IMPORTED_MODULE_9__._getEventTarget)(event);

    if (!elementInfo || !elementInfo.checkChildren && element !== focusEventTarget) {
      return;
    }

    this._originChanged(element, this._getFocusOrigin(focusEventTarget), elementInfo);
  }
  /**
   * Handles blur events on a registered element.
   * @param event The blur event.
   * @param element The monitored element.
   */


  _onBlur(event, element) {
    // If we are counting child-element-focus as focused, make sure that we aren't just blurring in
    // order to focus another child of the monitored element.
    const elementInfo = this._elementInfo.get(element);

    if (!elementInfo || elementInfo.checkChildren && event.relatedTarget instanceof Node && element.contains(event.relatedTarget)) {
      return;
    }

    this._setClasses(element);

    this._emitOrigin(elementInfo.subject, null);
  }

  _emitOrigin(subject, origin) {
    this._ngZone.run(() => subject.next(origin));
  }

  _registerGlobalListeners(elementInfo) {
    if (!this._platform.isBrowser) {
      return;
    }

    const rootNode = elementInfo.rootNode;
    const rootNodeFocusListeners = this._rootNodeFocusListenerCount.get(rootNode) || 0;

    if (!rootNodeFocusListeners) {
      this._ngZone.runOutsideAngular(() => {
        rootNode.addEventListener('focus', this._rootNodeFocusAndBlurListener, captureEventListenerOptions);
        rootNode.addEventListener('blur', this._rootNodeFocusAndBlurListener, captureEventListenerOptions);
      });
    }

    this._rootNodeFocusListenerCount.set(rootNode, rootNodeFocusListeners + 1); // Register global listeners when first element is monitored.


    if (++this._monitoredElementCount === 1) {
      // Note: we listen to events in the capture phase so we
      // can detect them even if the user stops propagation.
      this._ngZone.runOutsideAngular(() => {
        const window = this._getWindow();

        window.addEventListener('focus', this._windowFocusListener);
      }); // The InputModalityDetector is also just a collection of global listeners.


      this._inputModalityDetector.modalityDetected.pipe((0,rxjs_operators__WEBPACK_IMPORTED_MODULE_17__.takeUntil)(this._stopInputModalityDetector)).subscribe(modality => {
        this._setOrigin(modality, true
        /* isFromInteraction */
        );
      });
    }
  }

  _removeGlobalListeners(elementInfo) {
    const rootNode = elementInfo.rootNode;

    if (this._rootNodeFocusListenerCount.has(rootNode)) {
      const rootNodeFocusListeners = this._rootNodeFocusListenerCount.get(rootNode);

      if (rootNodeFocusListeners > 1) {
        this._rootNodeFocusListenerCount.set(rootNode, rootNodeFocusListeners - 1);
      } else {
        rootNode.removeEventListener('focus', this._rootNodeFocusAndBlurListener, captureEventListenerOptions);
        rootNode.removeEventListener('blur', this._rootNodeFocusAndBlurListener, captureEventListenerOptions);

        this._rootNodeFocusListenerCount.delete(rootNode);
      }
    } // Unregister global listeners when last element is unmonitored.


    if (! --this._monitoredElementCount) {
      const window = this._getWindow();

      window.removeEventListener('focus', this._windowFocusListener); // Equivalently, stop our InputModalityDetector subscription.

      this._stopInputModalityDetector.next(); // Clear timeouts for all potentially pending timeouts to prevent the leaks.


      clearTimeout(this._windowFocusTimeoutId);
      clearTimeout(this._originTimeoutId);
    }
  }
  /** Updates all the state on an element once its focus origin has changed. */


  _originChanged(element, origin, elementInfo) {
    this._setClasses(element, origin);

    this._emitOrigin(elementInfo.subject, origin);

    this._lastFocusOrigin = origin;
  }
  /**
   * Collects the `MonitoredElementInfo` of a particular element and
   * all of its ancestors that have enabled `checkChildren`.
   * @param element Element from which to start the search.
   */


  _getClosest