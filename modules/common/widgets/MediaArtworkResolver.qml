pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

QtObject {
    id: root

    property string sourceUrl: ""
    property string title: ""
    property string artist: ""
    property string album: ""
    property string cacheDirectory: Directories.coverArt
    property int localReloadPasses: 8
    property bool ready: false
    property string displaySource: ""

    readonly property string normalizedSourceUrl: root._normalizeUrl(root.sourceUrl)
    readonly property bool isLocalFile: root.normalizedSourceUrl.startsWith("file://")
    readonly property bool isDataUri: root.normalizedSourceUrl.startsWith("data:")
    readonly property bool isRemote: root.normalizedSourceUrl.startsWith("http://") || root.normalizedSourceUrl.startsWith("https://")
    readonly property string metadataKey: [root.normalizedSourceUrl, root.title, root.artist, root.album].join("\u001f")
    readonly property string localFilePath: root.isLocalFile ? root._pathFromFileUrl(root.normalizedSourceUrl) : ""
    readonly property string artFileName: root.isRemote && root.normalizedSourceUrl.length > 0 ? Qt.md5(root.normalizedSourceUrl) : ""
    readonly property string artFilePath: root.artFileName.length > 0 ? `${root.cacheDirectory}/${root.artFileName}` : ""

    property int _generation: 0
    property int _retryCount: 0
    readonly property int _maxRetries: 3
    property int _localReloadsLeft: 0
    property bool _completed: false

    function _normalizeUrl(url): string {
        if (!url)
            return "";

        const value = url.toString();
        if (!value.length)
            return "";

        if (value.startsWith("data:") && value.length > 100000)
            return "";

        if (value.startsWith("/"))
            return "file://" + value;

        return value;
    }

    function _pathFromFileUrl(url: string): string {
        if (!url.startsWith("file://"))
            return "";

        const path = url.replace(/^file:\/\/localhost/, "").replace(/^file:\/\//, "");
        return decodeURIComponent(path.startsWith("/") ? path : "/" + path);
    }

    function _cacheBust(url: string): string {
        if (!url)
            return "";

        const value = url.toString();
        if (value.startsWith("data:"))
            return value;

        const separator = value.indexOf("?") >= 0 ? "&" : "?";
        return `${value}${separator}inir_art=${Qt.md5(root.metadataKey + ":" + root._generation)}`;
    }

    function _setReadySource(url: string): void {
        root._generation += 1;
        root.ready = true;
        root.displaySource = root._cacheBust(url);
    }

    function _stopWorkers(): void {
        if (!root._completed)
            return;

        artExistsChecker.running = false;
        artworkDownloader.running = false;
        localExistsChecker.running = false;
        retryTimer.stop();
        localReloadTimer.stop();
    }

    function _reset(): void {
        root._stopWorkers();
        root.ready = false;
        root.displaySource = "";
        root._retryCount = 0;
        root._localReloadsLeft = root.localReloadPasses;
    }

    function refresh(): void {
        const url = root.normalizedSourceUrl;
        if (!url.length) {
            root._reset();
            return;
        }

        if (root.isDataUri) {
            root._setReadySource(url);
            return;
        }

        if (root.isLocalFile) {
            if (!root.localFilePath.length) {
                root._setReadySource(url);
                return;
            }

            localExistsChecker.filePath = root.localFilePath;
            localExistsChecker.running = false;
            localExistsChecker.running = true;
            return;
        }

        if (root.isRemote && root.artFilePath.length > 0) {
            artExistsChecker.artFilePath = root.artFilePath;
            artExistsChecker.running = false;
            artExistsChecker.running = true;
            return;
        }

        root._setReadySource(url);
    }

    onMetadataKeyChanged: {
        if (!root._completed)
            return;

        root._reset();
        root.refresh();
    }

    onCacheDirectoryChanged: {
        if (!root._completed)
            return;

        root._reset();
        root.refresh();
    }

    Component.onCompleted: {
        root._completed = true;
        root._localReloadsLeft = root.localReloadPasses;
        root.refresh();
    }

    property var localReloadTimer: Timer {
        interval: 250
        repeat: false
        onTriggered: {
            if (!root.normalizedSourceUrl.length || !root.isLocalFile)
                return;

            root.refresh();
        }
    }

    property var retryTimer: Timer {
        interval: 350 * Math.max(1, root._retryCount)
        repeat: false
        onTriggered: root.refresh()
    }

    property var localExistsChecker: Process {
        property string filePath: ""

        command: ["/usr/bin/test", "-s", filePath]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 && exitCode !== 1)
                return;

            if (filePath !== root.localFilePath)
                return;

            if (exitCode === 0)
                root._setReadySource(root.normalizedSourceUrl);

            if (root._localReloadsLeft > 0) {
                root._localReloadsLeft -= 1;
                localReloadTimer.restart();
            }
        }
    }

    property var artExistsChecker: Process {
        property string artFilePath: ""

        command: ["/usr/bin/test", "-s", artFilePath]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 && exitCode !== 1)
                return;

            if (artFilePath !== root.artFilePath)
                return;

            if (exitCode === 0) {
                root._setReadySource(Qt.resolvedUrl(artFilePath));
            } else {
                artworkDownloader.targetFile = root.normalizedSourceUrl;
                artworkDownloader.artFilePath = artFilePath;
                artworkDownloader.running = false;
                artworkDownloader.running = true;
            }
        }
    }

    property var artworkDownloader: Process {
        property string targetFile: ""
        property string artFilePath: ""

        command: ["/usr/bin/bash", "-c", `
            target="$1"
            out="$2"
            dir="$3"
            if [ -z "$target" ] || [ -z "$out" ]; then exit 1; fi
            if [ -f "$out" ]; then exit 0; fi
            mkdir -p "$dir"
            tmp="$out.tmp.$$"
            /usr/bin/curl -sSL --connect-timeout 4 --max-time 12 "$target" -o "$tmp" && \
            [ -s "$tmp" ] && /usr/bin/mv -f "$tmp" "$out" || { rm -f "$tmp"; exit 1; }
        `, "_", targetFile, artFilePath, root.cacheDirectory]

        onExited: (exitCode) => {
            if (artFilePath !== root.artFilePath)
                return;

            if (exitCode === 0) {
                root._retryCount = 0;
                root._setReadySource(Qt.resolvedUrl(artFilePath));
            } else if (root._retryCount < root._maxRetries) {
                root._retryCount += 1;
                retryTimer.restart();
            }
        }
    }
}
