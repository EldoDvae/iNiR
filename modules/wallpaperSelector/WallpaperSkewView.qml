pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects as GE
import Quickshell

Item {
    id: root

    required property var folderModel
    required property string currentWallpaperPath
    property bool useDarkMode: Appearance.m3colors.darkmode

    signal wallpaperSelected(string filePath)
    signal directorySelected(string dirPath)
    signal closeRequested()
    signal switchToGridRequested()
    signal switchToGalleryRequested()

    // ═══════════════════════════════════════════════════
    // STATE
    // ═══════════════════════════════════════════════════
    readonly property int totalCount: folderModel?.count ?? 0
    readonly property bool hasItems: totalCount > 0
    readonly property string currentFolderPath: String(folderModel?.folder ?? "")
    readonly property string currentFolderName: FileUtils.folderNameForPath(currentFolderPath)
    readonly property bool canGoBack: (folderModel?.currentFolderHistoryIndex ?? 0) > 0
    readonly property bool canGoForward: (folderModel?.currentFolderHistoryIndex ?? 0) < ((folderModel?.folderHistory?.length ?? 0) - 1)
    readonly property real _dpr: root.window ? root.window.devicePixelRatio : 1

    // Active item derived state (same pattern as CoverflowView)
    readonly property string activePath: hasItems ? _filePath(currentIndex) : ""
    readonly property string activeName: hasItems ? _fileName(currentIndex) : ""
    readonly property bool activeIsDir: hasItems ? _fileIsDir(currentIndex) : false
    readonly property string activeQuantizerSource: {
        if (!hasItems || activeIsDir || activePath.length === 0) return ""
        const lower = activeName.toLowerCase()
        const isVideo = lower.endsWith(".mp4") || lower.endsWith(".webm") || lower.endsWith(".mkv") || lower.endsWith(".avi") || lower.endsWith(".mov")
        const isGif = lower.endsWith(".gif")
        if (isVideo || isGif) {
            const thumbPath = Wallpapers.getExpectedThumbnailPath(activePath, "x-large")
            return thumbPath.length > 0 ? ("file://" + thumbPath) : ""
        }
        return "file://" + activePath
    }

    property int currentIndex: 0
    property bool showKeyboardGuide: true
    property bool _snapDone: false  // controls highlightMoveDuration: false=instant, true=animated
    property real _focusPulse: 0
    property int _wheelAccum: 0

    // ─── Skew parameters ───
    readonly property real skewFactor: -0.30
    readonly property int cardWidth: Math.round(Math.min(root.width * 0.22, 320))
    readonly property int cardHeight: Math.round(cardWidth * 1.4)

    // ═══════════════════════════════════════════════════
    // STYLE TOKENS (from CoverflowView)
    // ═══════════════════════════════════════════════════
    readonly property color surfaceColor: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
        : Appearance.colors.colLayer1
    readonly property color baseColor: Appearance.angelEverywhere ? Appearance.angel.colGlassPanel
        : Appearance.inirEverywhere ? Appearance.inir.colLayer0
        : Appearance.auroraEverywhere ? Appearance.aurora.colOverlay
        : Appearance.colors.colLayer0
    readonly property color textColor: Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.inirEverywhere ? Appearance.inir.colText
        : Appearance.colors.colOnLayer1
    readonly property color borderColor: Appearance.angelEverywhere ? Appearance.angel.colBorderSubtle
        : Appearance.inirEverywhere ? Appearance.inir.colBorderSubtle
        : ColorUtils.applyAlpha(Appearance.colors.colOutlineVariant, 0.45)
    readonly property real cardRadius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
        : Appearance.rounding.small

    // ═══════════════════════════════════════════════════
    // ACCENT COLOR (single ColorQuantizer, debounced)
    // ═══════════════════════════════════════════════════
    property string _debouncedQuantizerSource: ""
    Timer {
        id: quantizerDebounce
        interval: 280
        onTriggered: root._debouncedQuantizerSource = root.activeQuantizerSource
    }
    onActiveQuantizerSourceChanged: quantizerDebounce.restart()

    ColorQuantizer {
        id: quantizer
        source: root._debouncedQuantizerSource
        depth: 0
        rescaleSize: 10
    }

    readonly property color accentColor: {
        const c = quantizer?.colors?.[0]
        if (!c || root.activeIsDir || root.activePath.length === 0)
            return Appearance.colors.colPrimary
        return ColorUtils.mix(c, Appearance.colors.colPrimary, 0.45)
    }

    property color _accent: accentColor
    Behavior on _accent {
        enabled: Appearance.animationsEnabled
        ColorAnimation {
            duration: Appearance.animation.elementMoveEnter.duration
            easing.type: Appearance.animation.elementMoveEnter.type
            easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
        }
    }

    // ═══════════════════════════════════════════════════
    // FOCUS PULSE (from CoverflowView)
    // ═══════════════════════════════════════════════════
    SequentialAnimation {
        id: focusPulseAnim
        running: false
        NumberAnimation {
            target: root; property: "_focusPulse"; to: 1
            duration: Math.max(1, Appearance.animation.clickBounce.duration * 0.5)
            easing.type: Appearance.animation.clickBounce.type
            easing.bezierCurve: Appearance.animation.clickBounce.bezierCurve
        }
        NumberAnimation {
            target: root; property: "_focusPulse"; to: 0
            duration: Math.max(1, Appearance.animation.clickBounce.duration * 0.8)
            easing.type: Appearance.animation.clickBounce.type
            easing.bezierCurve: Appearance.animation.clickBounce.bezierCurve
        }
    }

    // ═══════════════════════════════════════════════════
    // MODEL HELPERS
    // ═══════════════════════════════════════════════════
    function _filePath(i)  { return (i >= 0 && i < totalCount) ? (folderModel.get(i, "filePath") ?? "")  : "" }
    function _fileName(i)  { return (i >= 0 && i < totalCount) ? (folderModel.get(i, "fileName") ?? "")  : "" }
    function _fileIsDir(i) { return (i >= 0 && i < totalCount) ? (folderModel.get(i, "fileIsDir") ?? false) : false }
    function _fileUrl(i)   { return (i >= 0 && i < totalCount) ? (folderModel.get(i, "fileUrl") ?? "")   : "" }
    function _mediaKind(name: string, isDir: bool): string {
        if (isDir) return "dir"
        const l = name.toLowerCase()
        if (l.endsWith(".mp4") || l.endsWith(".webm") || l.endsWith(".mkv") || l.endsWith(".avi") || l.endsWith(".mov")) return "video"
        if (l.endsWith(".gif")) return "gif"
        return "image"
    }

    // ═══════════════════════════════════════════════════
    // NAVIGATION (from CoverflowView)
    // ═══════════════════════════════════════════════════
    function _goToIndex(index: int): void {
        if (!hasItems) return
        const next = Math.max(0, Math.min(totalCount - 1, index))
        if (next === currentIndex) return
        currentIndex = next
        showKeyboardGuide = false
    }

    function moveSelection(delta: int): void {
        _goToIndex(currentIndex + delta)
    }

    function activateCurrent(): void {
        if (!hasItems) return
        const path = _filePath(currentIndex)
        if (!path || path.length === 0) return
        showKeyboardGuide = false
        if (_fileIsDir(currentIndex))
            directorySelected(path)
        else
            wallpaperSelected(path)
    }

    // Wallpaper detection: find current wallpaper index
    function _findCurrentWallpaperIndex(): int {
        const target = FileUtils.trimFileProtocol(String(currentWallpaperPath ?? ""))
        if (target.length === 0 || totalCount === 0) return -1
        for (let i = 0; i < totalCount; i++) {
            if (FileUtils.trimFileProtocol(_filePath(i)) === target)
                return i
        }
        return -1
    }

    // Schedule initial scroll — always deferred to let layout settle
    function _scheduleInitialScroll(): void {
        if (_snapDone) return
        initialSnapTimer.restart()
    }

    // Deferred snap — runs AFTER layout is ready, re-finds wallpaper fresh
    // (currentIndex may have been reset by ListView model initialization)
    Timer {
        id: initialSnapTimer
        interval: 80
        property int _retries: 0
        onTriggered: {
            if (skewView.width <= 0) {
                if (_retries < 10) {
                    _retries++
                    initialSnapTimer.restart()
                }
                return
            }
            const idx = root._findCurrentWallpaperIndex()
            if (idx >= 0) {
                root.currentIndex = idx
                skewView.positionViewAtIndex(idx, ListView.Center)
            }
            // Enable animated navigation from now on
            root._snapDone = true
            _retries = 0
        }
    }

    // ═══════════════════════════════════════════════════
    // LIFECYCLE
    // ═══════════════════════════════════════════════════
    function updateThumbnails(): void {
        for (let i = 0; i < Math.min(totalCount, 30); i++) {
            const fp = _filePath(i)
            if (fp && fp.length > 0 && !_fileIsDir(i)) {
                Wallpapers.ensureThumbnailForPath(fp, "x-large")
                if (_mediaKind(_fileName(i), false) === "video")
                    Wallpapers.ensureVideoFirstFrame(fp)
            }
        }
    }

    onTotalCountChanged: {
        if (!_snapDone && totalCount > 0)
            _scheduleInitialScroll()
    }
    Component.onCompleted: {
        if (totalCount > 0)
            _scheduleInitialScroll()
        updateThumbnails()
    }

    Connections {
        target: root.folderModel
        function onFolderChanged() {
            root._snapDone = false
            root.currentIndex = 0
            root._scheduleInitialScroll()
        }
    }

    // ═══════════════════════════════════════════════════
    // INPUT (keyboard + wheel, from CoverflowView)
    // ═══════════════════════════════════════════════════
    Keys.onPressed: event => {
        const alt = (event.modifiers & Qt.AltModifier) !== 0
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0
        const shift = (event.modifiers & Qt.ShiftModifier) !== 0

        if (!searchField.activeFocus && (ctrl && event.key === Qt.Key_F || event.key === Qt.Key_Slash)) {
            root.showKeyboardGuide = false
            searchField.forceActiveFocus(); event.accepted = true; return
        }

        if (searchField.activeFocus) {
            if (event.key === Qt.Key_Escape) {
                if (searchField.text.length > 0) Wallpapers.searchQuery = ""
                else { searchField.focus = false; root.forceActiveFocus() }
                event.accepted = true
            }
            return
        }

        switch (event.key) {
        case Qt.Key_Escape:
            root.closeRequested(); break
        case Qt.Key_Left:
            if (alt || ctrl) Wallpapers.navigateBack()
            else root.moveSelection(-(shift ? 3 : 1))
            break
        case Qt.Key_Right:
            if (alt || ctrl) Wallpapers.navigateForward()
            else root.moveSelection(shift ? 3 : 1)
            break
        case Qt.Key_Home:
            root._goToIndex(0); break
        case Qt.Key_End:
            root._goToIndex(root.totalCount - 1); break
        case Qt.Key_Return: case Qt.Key_Enter:
            root.activateCurrent(); break
        case Qt.Key_Backspace:
            if (alt || ctrl) Wallpapers.navigateUp()
            break
        default:
            event.accepted = false; return
        }
        event.accepted = true
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            root.showKeyboardGuide = false
            const d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
            root._wheelAccum += d
            const steps = root._wheelAccum >= 0
                ? Math.floor(root._wheelAccum / 120)
                : Math.ceil(root._wheelAccum / 120)
            if (steps !== 0) {
                root._wheelAccum -= steps * 120
                root.moveSelection(-steps)
            }
        }
    }

    // ═══════════════════════════════════════════════════
    // MAIN SKEW LISTVIEW
    // ═══════════════════════════════════════════════════
    ListView {
        id: skewView
        anchors {
            fill: parent
            topMargin: 40
            bottomMargin: toolbarArea.height + hintBar.height + 50
        }

        orientation: ListView.Horizontal
        spacing: 0
        clip: false
        cacheBuffer: 1200
        focus: false

        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: (width / 2) - (root.cardWidth / 2)
        preferredHighlightEnd: (width / 2) + (root.cardWidth / 2)
        highlightMoveDuration: root._snapDone ? 300 : 0
        highlightFollowsCurrentItem: true

        boundsBehavior: Flickable.StopAtBounds
        model: root.totalCount
        currentIndex: root.currentIndex

        onCurrentIndexChanged: {
            if (currentIndex !== root.currentIndex)
                root.currentIndex = currentIndex
        }

        delegate: Item {
            id: delegateRoot
            required property int index
            readonly property string filePath: root._filePath(index)
            readonly property string fileName: root._fileName(index)
            readonly property bool fileIsDir: root._fileIsDir(index)
            readonly property string mediaKind: root._mediaKind(fileName, fileIsDir)
            readonly property bool isCurrent: ListView.isCurrentItem
            readonly property bool isActive: filePath.length > 0 && filePath === root.currentWallpaperPath

            width: root.cardWidth
            height: root.cardHeight
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            z: isCurrent ? 10 : 1

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.showKeyboardGuide = false
                    if (root.currentIndex === index)
                        root.activateCurrent()
                    else
                        root._goToIndex(index)
                }
            }

            Item {
                id: cardVisual
                anchors.centerIn: parent
                width: parent.width
                height: parent.height

                scale: delegateRoot.isCurrent ? 1.15 : 0.95
                opacity: delegateRoot.isCurrent ? 1.0 : 0.6

                Behavior on scale { NumberAnimation { duration: 500; easing.type: Easing.OutBack } }
                Behavior on opacity { NumberAnimation { duration: 500 } }

                // Parallelogram skew
                transform: Matrix4x4 {
                    property real s: root.skewFactor
                    matrix: Qt.matrix4x4(1, s, 0, 0,
                                         0, 1, 0, 0,
                                         0, 0, 1, 0,
                                         0, 0, 0, 1)
                }

                // Card body
                Rectangle {
                    id: card
                    anchors.fill: parent
                    radius: root.cardRadius
                    color: "transparent"
                    clip: true
                    border.width: delegateRoot.isCurrent ? 2.5 : delegateRoot.isActive ? 2 : 1
                    border.color: delegateRoot.isCurrent ? root._accent
                        : delegateRoot.isActive ? Appearance.colors.colPrimary
                        : root.borderColor

                    Behavior on border.color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }

                    // Background behind image (visible in corners / while loading)
                    Rectangle {
                        anchors.fill: parent
                        color: root.baseColor
                        z: -1
                    }

                    // Wallpaper image — counter-skewed so the image appears straight
                    ThumbnailImage {
                        visible: !delegateRoot.fileIsDir && delegateRoot.filePath.length > 0 && delegateRoot.mediaKind !== "video"
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: Math.round(-parent.height * Math.abs(root.skewFactor) * 0.35)
                        width: parent.width + Math.round(parent.height * Math.abs(root.skewFactor)) + Math.round(parent.width * 0.15)
                        height: parent.height
                        fillMode: Image.PreserveAspectCrop
                        generateThumbnail: true
                        sourcePath: delegateRoot.filePath
                        thumbnailSizeName: "x-large"
                        cache: true
                        asynchronous: true
                        retainWhileLoading: true
                        mipmap: true
                        sourceSize.width: Math.round(root.cardWidth * 1.6 * root._dpr)
                        sourceSize.height: Math.round(root.cardHeight * root._dpr)

                        transform: Matrix4x4 {
                            property real s: -root.skewFactor
                            matrix: Qt.matrix4x4(1, s, 0, 0,
                                                 0, 1, 0, 0,
                                                 0, 0, 1, 0,
                                                 0, 0, 0, 1)
                        }
                    }

                    // Video first frame
                    Image {
                        visible: delegateRoot.mediaKind === "video"
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: Math.round(-parent.height * Math.abs(root.skewFactor) * 0.35)
                        width: parent.width + Math.round(parent.height * Math.abs(root.skewFactor)) + Math.round(parent.width * 0.15)
                        height: parent.height
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        source: {
                            if (!visible) return ""
                            const ff = Wallpapers.videoFirstFrames[delegateRoot.filePath]
                            return ff ? (ff.startsWith("file://") ? ff : "file://" + ff) : ""
                        }
                        Component.onCompleted: {
                            if (delegateRoot.mediaKind === "video")
                                Wallpapers.ensureVideoFirstFrame(delegateRoot.filePath)
                        }

                        transform: Matrix4x4 {
                            property real s: -root.skewFactor
                            matrix: Qt.matrix4x4(1, s, 0, 0,
                                                 0, 1, 0, 0,
                                                 0, 0, 1, 0,
                                                 0, 0, 0, 1)
                        }
                    }

                    // Directory icon
                    Loader {
                        active: delegateRoot.fileIsDir
                        anchors.fill: parent
                        sourceComponent: Column {
                            anchors.centerIn: parent
                            spacing: 8
                            MaterialSymbol {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "folder"
                                iconSize: 48
                                color: root.textColor
                                opacity: 0.7
                            }
                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: delegateRoot.fileName
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: root.textColor
                                opacity: 0.6
                                width: root.cardWidth - 24
                                elide: Text.ElideMiddle
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    // Dim overlay for non-current cards (depth effect)
                    Rectangle {
                        anchors.fill: parent
                        radius: card.radius
                        color: root.baseColor
                        opacity: delegateRoot.isCurrent ? 0.0 : 0.08
                    }

                    // Video/GIF badge
                    Rectangle {
                        visible: delegateRoot.mediaKind === "video" || delegateRoot.mediaKind === "gif"
                        anchors { top: parent.top; right: parent.right; margins: 10 }
                        width: 34; height: 34; radius: 8
                        color: ColorUtils.applyAlpha(Appearance.colors.colScrim, 0.6)

                        transform: Matrix4x4 {
                            property real s: -root.skewFactor
                            matrix: Qt.matrix4x4(1, s, 0, 0,
                                                 0, 1, 0, 0,
                                                 0, 0, 1, 0,
                                                 0, 0, 0, 1)
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: delegateRoot.mediaKind === "video" ? "play_arrow" : "gif"
                            iconSize: 18
                            color: Appearance.colors.colOnLayer0
                        }
                    }

                    // "Current" badge
                    Rectangle {
                        visible: delegateRoot.isActive && !delegateRoot.fileIsDir
                        anchors { bottom: parent.bottom; right: parent.right; margins: 10 }
                        implicitWidth: currentLabel.implicitWidth + 14
                        implicitHeight: currentLabel.implicitHeight + 6
                        radius: height / 2
                        color: ColorUtils.applyAlpha(root._accent, 0.9)

                        transform: Matrix4x4 {
                            property real s: -root.skewFactor
                            matrix: Qt.matrix4x4(1, s, 0, 0,
                                                 0, 1, 0, 0,
                                                 0, 0, 1, 0,
                                                 0, 0, 0, 1)
                        }

                        StyledText {
                            id: currentLabel
                            anchors.centerIn: parent
                            text: Translation.tr("Active")
                            color: ColorUtils.contrastColor(root._accent)
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }
        }
    }

    // ─── Counter ───
    StyledText {
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
            topMargin: 14
        }
        visible: root.hasItems
        text: (root.currentIndex + 1) + " / " + root.totalCount
        font.pixelSize: Appearance.font.pixelSize.small
        color: root.textColor
        opacity: 0.5
    }

    // ─── Keyboard hint ───
    Rectangle {
        id: hintBar
        anchors {
            bottom: toolbarArea.top
            bottomMargin: 12
            horizontalCenter: parent.horizontalCenter
        }
        visible: root.showKeyboardGuide
        opacity: visible ? 1.0 : 0.0
        z: 220
        radius: height / 2
        color: ColorUtils.applyAlpha(Appearance.colors.colScrim, 0.72)
        width: hintText.implicitWidth + 24
        height: hintText.implicitHeight + 10
        Behavior on opacity { enabled: Appearance.animationsEnabled; animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }

        StyledText {
            id: hintText
            anchors.centerIn: parent
            text: Translation.tr("/ Search  ·  Enter Apply  ·  Esc Close")
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnLayer0
        }
    }

    // ─── Toolbar ───
    Toolbar {
        id: toolbarArea
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 22 }
        screenX: { const p = toolbarArea.mapToGlobal(0, 0); return p.x }
        screenY: { const p = toolbarArea.mapToGlobal(0, 0); return p.y }

        IconToolbarButton {
            implicitWidth: height
            enabled: root.canGoBack
            onClicked: Wallpapers.navigateBack()
            text: "arrow_back"
            StyledToolTip { text: Translation.tr("Back") }
        }
        IconToolbarButton {
            implicitWidth: height
            onClicked: Wallpapers.navigateUp()
            text: "arrow_upward"
            StyledToolTip { text: Translation.tr("Up") }
        }
        IconToolbarButton {
            implicitWidth: height
            enabled: root.canGoForward
            onClicked: Wallpapers.navigateForward()
            text: "arrow_forward"
            StyledToolTip { text: Translation.tr("Forward") }
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            Layout.maximumWidth: Math.min(root.width * 0.16, 200)
            font.pixelSize: Appearance.font.pixelSize.small
            color: root.textColor
            text: root.currentFolderName
            elide: Text.ElideMiddle
            maximumLineCount: 1
        }

        Rectangle {
            implicitWidth: 1; implicitHeight: 16
            color: Appearance.angelEverywhere ? Appearance.angel.colBorderSubtle
                 : Appearance.inirEverywhere ? Appearance.inir.colBorderSubtle
                 : Appearance.colors.colOnSurfaceVariant
            opacity: 0.2
        }

        IconToolbarButton {
            implicitWidth: height
            onClicked: {
                root.showKeyboardGuide = false
                root.useDarkMode = !root.useDarkMode
            }
            text: root.useDarkMode ? "dark_mode" : "light_mode"
            StyledToolTip { text: Translation.tr("Toggle light/dark mode") }
        }
        IconToolbarButton {
            implicitWidth: height
            onClicked: Wallpapers.randomFromCurrentFolder(root.useDarkMode)
            text: "shuffle"
            StyledToolTip { text: Translation.tr("Random wallpaper") }
        }

        Rectangle {
            implicitWidth: 1; implicitHeight: 16
            color: Appearance.angelEverywhere ? Appearance.angel.colBorderSubtle
                 : Appearance.inirEverywhere ? Appearance.inir.colBorderSubtle
                 : Appearance.colors.colOnSurfaceVariant
            opacity: 0.2
        }

        Item { Layout.fillWidth: true }

        ToolbarTextField {
            id: searchField
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: Math.min(root.width * 0.22, 340)
            implicitHeight: 38
            placeholderText: activeFocus ? Translation.tr("Search wallpapers") : Translation.tr("Hit \"/\" to search")
            text: Wallpapers.searchQuery
            onTextChanged: Wallpapers.searchQuery = text
            onActiveFocusChanged: if (activeFocus) root.showKeyboardGuide = false
        }

        IconToolbarButton {
            implicitWidth: height
            enabled: (Wallpapers.searchQuery ?? "").length > 0
            onClicked: Wallpapers.searchQuery = ""
            text: "backspace"
            StyledToolTip { text: Translation.tr("Clear search") }
        }

        Item { Layout.fillWidth: true }

        Rectangle {
            implicitWidth: 1; implicitHeight: 16
            color: Appearance.angelEverywhere ? Appearance.angel.colBorderSubtle
                 : Appearance.inirEverywhere ? Appearance.inir.colBorderSubtle
                 : Appearance.colors.colOnSurfaceVariant
            opacity: 0.2
        }

        IconToolbarButton {
            implicitWidth: height
            onClicked: root.switchToGalleryRequested()
            text: "view_carousel"
            StyledToolTip { text: Translation.tr("Gallery view") }
        }
        IconToolbarButton {
            implicitWidth: height
            onClicked: root.switchToGridRequested()
            text: "grid_view"
            StyledToolTip { text: Translation.tr("Grid view") }
        }

        IconToolbarButton {
            implicitWidth: height
            onClicked: root.closeRequested()
            text: "close"
            StyledToolTip { text: Translation.tr("Close") }
        }
    }
}
