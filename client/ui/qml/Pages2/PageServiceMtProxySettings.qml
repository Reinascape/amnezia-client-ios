import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import SortFilterProxyModel 0.2

import PageEnum 1.0
import ContainerProps 1.0
import ContainerEnum 1.0
import Style 1.0

import "./"
import "../Controls2"
import "../Controls2/TextTypes"
import "../Config"
import "../Components"

PageType {
    id: root

    // 0 = NotDeployed, 1 = Running, 2 = Stopped, 3 = Error
    property int containerStatus: 1
    property bool isUpdating: false
    property bool isCheckingStatus: false
    property bool previousEnabled: true
    property int previousContainerStatus: 1

    property string previousPort: ""
    property string previousTag: ""
    property string previousPublicHost: ""
    property string previousTransportMode: "standard"
    property string previousTlsDomain: ""
    property string previousWorkersMode: "auto"
    property string previousWorkers: "2"
    property bool   previousNatEnabled: false
    property string previousNatInternalIp: ""
    property string previousNatExternalIp: ""

    // Diagnostics
    property bool diagLoading: false
    property bool diagPortReachable: false
    property bool diagTelegramReachable: false
    property int  diagClientsConnected: -1
    property string diagLastConfigRefresh: ""
    property string diagStatsEndpoint: ""

    function statusText() {
        if (isCheckingStatus) return qsTr("Checking...")
        if (isUpdating) return qsTr("Updating")
        switch (containerStatus) {
            case 0:
                return qsTr("Not deployed")
            case 1:
                return qsTr("Running")
            case 2:
                return qsTr("Stopped")
            case 3:
                return qsTr("Error")
            default:
                return qsTr("Unknown")
        }
    }

    Component.onCompleted: {
        isCheckingStatus = true
        InstallController.refreshContainerStatus(ContainerEnum.MtProxy)
    }

    Connections {
        target: InstallController

        function onUpdateContainerFinished(message, closePage) {
            isUpdating = false
            PageController.showNotificationMessage(message)
            if (closePage) {
                PageController.closePage()
            }
        }

        function onRestartContainerFinished(message) {
            isUpdating = false
            PageController.showNotificationMessage(message)
        }

        function onInstallationErrorOccurred() {
            isUpdating = false
            containerStatus = previousContainerStatus
            MtProxyConfigModel.setEnabled(previousEnabled)
        }

        function onSetContainerEnabledFinished(enabled) {
            isUpdating = false
            containerStatus = enabled ? 1 : 2
            PageController.showNotificationMessage(
                enabled ? qsTr("MTProxy started") : qsTr("MTProxy stopped"))
        }

        function onContainerStatusRefreshed(status) {
            isCheckingStatus = false
            containerStatus = status
            if (status === 1) MtProxyConfigModel.setEnabled(true)
            else if (status === 2) MtProxyConfigModel.setEnabled(false)
        }

        function onMtProxyDiagnosticsRefreshed(portReachable, telegramReachable, clientsConnected, lastConfigRefresh, statsEndpoint) {
            diagLoading = false
            diagPortReachable = portReachable
            diagTelegramReachable = telegramReachable
            diagClientsConnected = clientsConnected
            diagLastConfigRefresh = lastConfigRefresh
            diagStatsEndpoint = statsEndpoint
        }
    }

    // ── Back button ──────────────────────────────────────────────────────────

    BackButtonType {
        id: backButton
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 20 + SettingsController.safeAreaTopMargin
        onFocusChanged: {
            if (this.activeFocus) connectionListView.positionViewAtBeginning()
        }
    }

    // ── Page header: title + enable switch + tabs ────────────────────────────

    ColumnLayout {
        id: pageHeader
        anchors.top: backButton.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 8
        spacing: 0

        BaseHeaderType {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.topMargin: 8
            headerText: qsTr("MTProxy settings")
        }

        LabelWithButtonType {
            Layout.fillWidth: true
            Layout.leftMargin: 0
            Layout.rightMargin: 16
            text: qsTr("Read more about this settings")
            textColor: AmneziaStyle.color.goldenApricot
            clickedFunction: function () {
                Qt.openUrlExternally("https://core.telegram.org/proxy")
            }
        }

        TabBar {
            id: mainTabBar
            Layout.fillWidth: true
            Layout.topMargin: 4

            background: Rectangle {
                color: AmneziaStyle.color.transparent
                Rectangle {
                    width: parent.width
                    height: 1
                    anchors.bottom: parent.bottom
                    color: AmneziaStyle.color.slateGray
                }
            }

            TabButtonType {
                text: qsTr("Connection")
                isSelected: mainTabBar.currentIndex === 0
                width: mainTabBar.width / 2
            }
            TabButtonType {
                text: qsTr("Settings")
                isSelected: mainTabBar.currentIndex === 1
                width: mainTabBar.width / 2
            }
        }
    }

    // ── Tab content ──────────────────────────────────────────────────────────

    StackLayout {
        id: tabContent
        anchors.top: pageHeader.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        currentIndex: mainTabBar.currentIndex

        // ════════════════════════════════════════════════════════════════════
        // CONNECTION TAB
        // ════════════════════════════════════════════════════════════════════

        ListViewType {
            id: connectionListView
            model: MtProxyConfigModel

            delegate: ColumnLayout {
                width: connectionListView.width
                spacing: 0

                // ── helpers ──────────────────────────────────────────────

                function domainToHex(domain) {
                    var hex = ""
                    for (var i = 0; i < domain.length; i++) {
                        var code = domain.charCodeAt(i).toString(16)
                        hex += (code.length < 2 ? "0" : "") + code
                    }
                    return hex
                }

                function secretForMode(mode) {
                    if (mode === "faketls") {
                        return tlsDomain !== "" ? "ee" + secret + domainToHex(tlsDomain) : "ee" + secret
                    } else if (mode === "padded") {
                        return "dd" + secret
                    }
                    return secret
                }

                property int secretTabIndex: transportMode === "faketls" ? 2 : 0

                function activeSecret() {
                    if (secretTabIndex === 0) return secretForMode("standard")
                    if (secretTabIndex === 1) return secretForMode("padded")
                    return secretForMode("faketls")
                }

                function effectiveSecret() {
                    return activeSecret()
                }

                function effectiveHost() {
                    return publicHost !== "" ? publicHost : ServersModel.getProcessedServerData("hostName")
                }

                function tmeLink() {
                    return "https://t.me/proxy?server=" + effectiveHost() + "&port=" + port + "&secret=" + activeSecret()
                }

                function tgLink() {
                    return "tg://proxy?server=" + effectiveHost() + "&port=" + port + "&secret=" + activeSecret()
                }

                // ── Telegram link ─────────────────────────────────────────

                CaptionTextType {
                    Layout.fillWidth: true
                    Layout.topMargin: 24
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.bottomMargin: 8
                    text: qsTr("Use Telegram connection link")
                    color: AmneziaStyle.color.mutedGray
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.bottomMargin: 16
                    implicitHeight: linkRow.implicitHeight + 16
                    color: AmneziaStyle.color.onyxBlack
                    radius: 8
                    border.color: AmneziaStyle.color.slateGray
                    border.width: 1

                    RowLayout {
                        id: linkRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        spacing: 4

                        CaptionTextType {
                            Layout.fillWidth: true
                            text: secret !== "" ? tmeLink() : qsTr("Deploy MTProxy first")
                            color: secret !== "" ? AmneziaStyle.color.goldenApricot : AmneziaStyle.color.mutedGray
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            font.pixelSize: 13
                        }

                        ImageButtonType {
                            implicitWidth: 36
                            implicitHeight: 36
                            hoverEnabled: true
                            image: "qrc:/images/controls/qr-code.svg"
                            imageColor: AmneziaStyle.color.paleGray
                            visible: secret !== ""
                            onClicked: {
                                // Вариант 1: fullscreen overlay (текущий)
                                qrOverlay.qrSource = MtProxyConfigModel.generateQrCode(tmeLink())
                                qrOverlay.linkUrl = tmeLink()
                                qrOverlay.visible = true

                                // Вариант 2: DrawerType2 снизу (закомментирован)
                                // qrDrawer.qrSource = MtProxyConfigModel.generateQrCode(tmeLink())
                                // qrDrawer.linkUrl = tmeLink()
                                // qrDrawer.openTriggered()
                            }
                        }

                        ImageButtonType {
                            implicitWidth: 36
                            implicitHeight: 36
                            hoverEnabled: true
                            image: "qrc:/images/controls/copy.svg"
                            imageColor: AmneziaStyle.color.paleGray
                            visible: secret !== ""
                            onClicked: {
                                GC.copyToClipBoard(tmeLink())
                                PageController.showNotificationMessage(qsTr("Copied"))
                            }
                        }
                    }
                }

                // tg:// link
                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.bottomMargin: 16
                    implicitHeight: tgLinkRow.implicitHeight + 16
                    color: AmneziaStyle.color.onyxBlack
                    radius: 8
                    border.color: AmneziaStyle.color.slateGray
                    border.width: 1
                    visible: secret !== ""

                    RowLayout {
                        id: tgLinkRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        spacing: 4

                        CaptionTextType {
                            Layout.fillWidth: true
                            text: tgLink()
                            color: AmneziaStyle.color.goldenApricot
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            font.pixelSize: 13
                        }

                        ImageButtonType {
                            implicitWidth: 36
                            implicitHeight: 36
                            hoverEnabled: true
                            image: "qrc:/images/controls/qr-code.svg"
                            imageColor: AmneziaStyle.color.paleGray
                            onClicked: {
                                qrOverlay.qrSource = MtProxyConfigModel.generateQrCode(tgLink())
                                qrOverlay.linkUrl = tgLink()
                                qrOverlay.visible = true
                            }
                        }

                        ImageButtonType {
                            implicitWidth: 36
                            implicitHeight: 36
                            hoverEnabled: true
                            image: "qrc:/images/controls/copy.svg"
                            imageColor: AmneziaStyle.color.paleGray
                            onClicked: {
                                GC.copyToClipBoard(tgLink())
                                PageController.showNotificationMessage(qsTr("Copied"))
                            }
                        }
                    }
                }

                // ── Manual details ────────────────────────────────────────

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.bottomMargin: 8
                    spacing: 4

                    CaptionTextType {
                        text: qsTr("Or enter the proxy details manually.")
                        color: AmneziaStyle.color.mutedGray
                    }

                    CaptionTextType {
                        Layout.fillWidth: true
                        text: qsTr("How to do it")
                        color: AmneziaStyle.color.goldenApricot
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Qt.openUrlExternally("https://core.telegram.org/proxy")
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.bottomMargin: 32
                    implicitHeight: manualCol.implicitHeight + 8
                    color: AmneziaStyle.color.onyxBlack
                    radius: 8
                    border.color: AmneziaStyle.color.slateGray
                    border.width: 1

                    ColumnLayout {
                        id: manualCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: 8
                        spacing: 0

                        // Host
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 12
                            Layout.rightMargin: 8
                            Layout.bottomMargin: 8
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                CaptionTextType {
                                    text: qsTr("Host")
                                    color: AmneziaStyle.color.mutedGray
                                    font.pixelSize: 12
                                }
                                CaptionTextType {
                                    Layout.fillWidth: true
                                    text: effectiveHost()
                                    color: AmneziaStyle.color.paleGray
                                    elide: Text.ElideRight
                                }
                            }
                            ImageButtonType {
                                implicitWidth: 36
                                implicitHeight: 36
                                hoverEnabled: true
                                image: "qrc:/images/controls/copy.svg"
                                imageColor: AmneziaStyle.color.paleGray
                                onClicked: { GC.copyToClipBoard(effectiveHost())
                                    PageController.showNotificationMessage(qsTr("Copied")) }
                            }
                        }

                        DividerType {
                            Layout.fillWidth: true
                        }

                        // Port
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 12
                            Layout.rightMargin: 8
                            Layout.topMargin: 8
                            Layout.bottomMargin: 8
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                CaptionTextType {
                                    text: qsTr("Port")
                                    color: AmneziaStyle.color.mutedGray
                                    font.pixelSize: 12
                                }
                                CaptionTextType {
                                    Layout.fillWidth: true
                                    text: port
                                    color: AmneziaStyle.color.paleGray
                                }
                            }
                            ImageButtonType {
                                implicitWidth: 36
                                implicitHeight: 36
                                hoverEnabled: true
                                image: "qrc:/images/controls/copy.svg"
                                imageColor: AmneziaStyle.color.paleGray
                                onClicked: { GC.copyToClipBoard(port)
                                    PageController.showNotificationMessage(qsTr("Copied")) }
                            }
                        }

                        DividerType {
                            Layout.fillWidth: true
                        }

                        // Secret tabs: Standard / Padded / FakeTLS
                        ButtonGroup {
                            id: secretTabGroup
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 12
                            Layout.rightMargin: 12
                            Layout.topMargin: 8
                            Layout.bottomMargin: 4
                            spacing: 4

                            HorizontalRadioButton {
                                Layout.fillWidth: true
                                text: qsTr("Standard")
                                ButtonGroup.group: secretTabGroup
                                checked: secretTabIndex === 0
                                onClicked: secretTabIndex = 0
                            }
                            HorizontalRadioButton {
                                Layout.fillWidth: true
                                text: qsTr("Padded")
                                ButtonGroup.group: secretTabGroup
                                checked: secretTabIndex === 1
                                onClicked: secretTabIndex = 1
                            }
                            HorizontalRadioButton {
                                Layout.fillWidth: true
                                text: qsTr("FakeTLS")
                                ButtonGroup.group: secretTabGroup
                                checked: secretTabIndex === 2
                                onClicked: secretTabIndex = 2
                                visible: transportMode === "faketls"
                            }
                        }

                        // Secret value + copy
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 12
                            Layout.rightMargin: 8
                            Layout.topMargin: 4
                            Layout.bottomMargin: 8
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                CaptionTextType {
                                    text: qsTr("Secret")
                                    color: AmneziaStyle.color.mutedGray
                                    font.pixelSize: 12
                                }
                                CaptionTextType {
                                    Layout.fillWidth: true
                                    text: activeSecret()
                                    color: AmneziaStyle.color.paleGray
                                    wrapMode: Text.WrapAnywhere
                                    font.pixelSize: 13
                                }
                            }
                            ImageButtonType {
                                implicitWidth: 36
                                implicitHeight: 36
                                hoverEnabled: true
                                image: "qrc:/images/controls/copy.svg"
                                imageColor: AmneziaStyle.color.paleGray
                                onClicked: { GC.copyToClipBoard(activeSecret())
                                    PageController.showNotificationMessage(qsTr("Copied")) }
                            }
                        }
                    }
                }

                // ── Delete ────────────────────────────────────────────────

                LabelWithButtonType {
                    id: removeButton
                    Layout.fillWidth: true
                    Layout.bottomMargin: 24
                    Layout.leftMargin: 0
                    Layout.rightMargin: 16
                    visible: ServersModel.isProcessedServerHasWriteAccess()
                    text: qsTr("Delete MTProxy")
                    textColor: AmneziaStyle.color.vibrantRed
                    clickedFunction: function () {
                        var headerText = qsTr("Remove %1 from server?").arg(ContainersModel.getProcessedContainerName())
                        var descriptionText = qsTr("The proxy will be stopped and all users will lose access.")
                        var yesButtonText = qsTr("Continue")
                        var noButtonText = qsTr("Cancel")
                        var yesButtonFunction = function () {
                            PageController.goToPage(PageEnum.PageDeinstalling)
                            InstallController.removeProcessedContainer()
                        }
                        showQuestionDrawer(headerText, descriptionText, yesButtonText, noButtonText, yesButtonFunction, function () {
                        })
                    }
                    MouseArea {
                        anchors.fill: removeButton
                        cursorShape: Qt.PointingHandCursor
                        enabled: false
                    }
                }
            }
        }

        // ════════════════════════════════════════════════════════════════════
        // SETTINGS TAB
        // ════════════════════════════════════════════════════════════════════

        ListViewType {
            id: settingsListView
            model: MtProxyConfigModel
            reuseItems: false

            delegate: ColumnLayout {
                width: settingsListView.width
                spacing: 0

                // ── Enable MTProxy ────────────────────────────────────────
                SwitcherType {
                    id: enableMtProxySwitch
                    Layout.fillWidth: true
                    Layout.topMargin: 24
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.bottomMargin: 16
                    text: qsTr("Enable MTProxy")
                    descriptionText: root.statusText()
                    checked: isEnabled
                    enabled: !isCheckingStatus && containerStatus !== 0 && containerStatus !== 3 && !isUpdating
                    onToggled: function () {
                        if (checked !== isEnabled) {
                            previousEnabled = isEnabled
                            previousContainerStatus = containerStatus
                            isEnabled = checked
                            isUpdating = true
                            InstallController.setContainerEnabled(ContainerEnum.MtProxy, checked)
                        }
                    }
                }

                // ── Base secret ───────────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 16
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.bottomMargin: 16 * 2
                    spacing: 4

                    CaptionTextType {
                        text: qsTr("Base secret")
                        color: AmneziaStyle.color.mutedGray
                        font.pixelSize: 12
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        CaptionTextType {
                            Layout.fillWidth: true
                            text: secret !== "" ? secret : qsTr("Not generated")
                            color: secret !== "" ? AmneziaStyle.color.paleGray : AmneziaStyle.color.mutedGray
                            elide: Text.ElideMiddle
                            font.pixelSize: 14
                        }

                        ImageButtonType {
                            implicitWidth: 36
                            implicitHeight: 36
                            hoverEnabled: true
                            image: "qrc:/images/controls/refresh-cw.svg"
                            imageColor: AmneziaStyle.color.paleGray
                            visible: ServersModel.isProcessedServerHasWriteAccess()
                            onClicked: {
                                showQuestionDrawer(
                                    qsTr("Generate new secret?"),
                                    qsTr("All existing connection links will stop working. Users will need new links."),
                                    qsTr("Generate"),
                                    qsTr("Cancel"),
                                        function () {
                                        isUpdating = true
                                        MtProxyConfigModel.generateSecret()
                                        InstallController.updateContainer(MtProxyConfigModel.getConfig(), false)
                                        InstallController.restartContainer(MtProxyConfigModel.getConfig())
                                    },
                                        function () {
                                    }
                                )
                            }
                        }
                    }
                }

                // ── Public host / IP ──────────────────────────────────────
                TextFieldWithHeaderType {
                    id: publicHostTextField
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.bottomMargin: 16
                    headerText: qsTr("Public host / IP")
                    textField.placeholderText: ServersModel.getProcessedServerData("hostName")
                    textField.text: publicHost
                    textField.onEditingFinished: {
                        textField.text = textField.text.replace(/^\s+|\s+$/g, '')
                        if (textField.text !== publicHost) {
                            publicHost = textField.text
                        }
                    }
                }

                // ── Server port ───────────────────────────────────────────
                TextFieldWithHeaderType {
                    id: portTextField
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.bottomMargin: 16
                    headerText: qsTr("Server port")
                    textField.placeholderText: "443"
                    textField.text: port
                    textField.maximumLength: 5
                    textField.validator: IntValidator {
                        bottom: 1
                        top: 65535
                    }
                    textField.onEditingFinished: {
                        textField.text = textField.text.replace(/^\s+|\s+$/g, '')
                        if (textField.text !== port) {
                            port = textField.text
                        }
                    }
                }

                CaptionTextType {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.bottomMargin: 12
                    visible: transportMode === "faketls" && portTextField.textField.text !== "443" && portTextField.textField.text !== ""
                    text: qsTr("FakeTLS may not work on ports other than 443")
                    color: AmneziaStyle.color.goldenApricot
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }

                // ── Promoted channel tag ──────────────────────────────────
                TextFieldWithHeaderType {
                    id: tagTextField
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.bottomMargin: 16
                    headerText: qsTr("Promoted channel tag (optional)")
                    textField.placeholderText: qsTr("leave empty if not needed")
                    textField.text: tag
                    textField.maximumLength: 64
                    textField.onEditingFinished: {
                        textField.text = textField.text.replace(/^\s+|\s+$/g, '')
                        if (textField.text !== tag) {
                            tag = textField.text
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.bottomMargin: 16
                    spacing: 4

                    CaptionTextType {
                        text: qsTr("Get a tag from")
                        color: AmneziaStyle.color.mutedGray
                        font.pixelSize: 12
                    }
                    CaptionTextType {
                        text: "@MTProxyBot"
                        color: AmneziaStyle.color.goldenApricot
                        font.pixelSize: 12
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Qt.openUrlExternally("https://t.me/MTProxyBot")
                        }
                    }
                }

                // ── Transport mode dropdown ───────────────────────────────
                DropDownType {
                    id: transportModeDropDown
                    Layout.fillWidth: true
                    Layout.topMargin: 16 * 2
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.bottomMargin: 16

                    drawerParent: root
                    drawerHeight: 0.35
                    descriptionText: qsTr("Transport mode")
                    text: transportMode === "faketls" ? qsTr("FakeTLS") : qsTr("Standard MTProto")

                    listView: Component {
                        ListViewType {
                            model: [qsTr("Standard MTProto"), qsTr("FakeTLS")]
                            delegate: LabelWithButtonType {
                                Layout.fillWidth: true
                                text: modelData
                                rightImageSource: {
                                    var isCurrent = (index === 0 && transportMode === "standard") ||
                                        (index === 1 && transportMode === "faketls")
                                    return isCurrent ? "qrc:/images/controls/check.svg" : ""
                                }
                                rightImageColor: AmneziaStyle.color.goldenApricot
                                clickedFunction: function () {
                                    transportMode = (index === 0) ? "standard" : "faketls"
                                    transportModeDropDown.closeTriggered()
                                }
                            }
                        }
                    }
                }

                // ── FakeTLS domain ────────────────────────────────────────
                TextFieldWithHeaderType {
                    id: tlsDomainTextField
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.bottomMargin: 16
                    visible: transportMode === "faketls"
                    headerText: qsTr("FakeTLS domain")
                    textField.placeholderText: "google.com"
                    textField.text: tlsDomain
                    textField.onEditingFinished: {
                        textField.text = textField.text.replace(/^\s+|\s+$/g, '')
                        if (textField.text !== tlsDomain) {
                            tlsDomain = textField.text
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.bottomMargin: 16
                    spacing: 4
                    visible: transportMode === "faketls"

                    CaptionTextType {
                        Layout.fillWidth: true
                        text: qsTr("The domain is encoded into the FakeTLS client secret (ee + base_secret + hex(domain)). It must support HTTPS / TLS 1.3.")
                        color: AmneziaStyle.color.mutedGray
                        wrapMode: Text.WordWrap
                        font.pixelSize: 12
                    }
                    CaptionTextType {
                        Layout.fillWidth: true
                        text: qsTr("\u26a0 Changing the domain will invalidate all previously issued FakeTLS connection links.")
                        color: AmneziaStyle.color.goldenApricot
                        wrapMode: Text.WordWrap
                        font.pixelSize: 12
                    }
                }

                // ── Advanced (collapsible) ────────────────────────────────
                LabelWithButtonType {
                    id: advancedHeader
                    Layout.fillWidth: true
                    Layout.leftMargin: 0
                    Layout.rightMargin: 16
                    property bool expanded: false
                    text: qsTr("Advanced")
                    rightImageSource: expanded
                        ? "qrc:/images/controls/chevron-up.svg"
                        : "qrc:/images/controls/chevron-down.svg"
                    rightImageColor: AmneziaStyle.color.mutedGray
                    clickedFunction: function () {
                        expanded = !expanded
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    visible: advancedHeader.expanded

                    // Additional secrets
                    CaptionTextType {
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        Layout.topMargin: 8
                        Layout.bottomMargin: 4
                        text: qsTr("Additional secrets")
                        color: AmneziaStyle.color.mutedGray
                    }
                    CaptionTextType {
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        Layout.bottomMargin: 8
                        text: qsTr("Add extra secrets to allow gradual migration without disconnecting existing users.")
                        color: AmneziaStyle.color.charcoalGray
                        wrapMode: Text.WordWrap
                        font.pixelSize: 12
                    }

                    Repeater {
                        model: additionalSecrets
                        delegate: RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 16
                            Layout.rightMargin: 16
                            Layout.bottomMargin: 4
                            spacing: 8
                            CaptionTextType {
                                Layout.fillWidth: true
                                text: modelData
                                color: AmneziaStyle.color.paleGray
                                elide: Text.ElideMiddle
                                font.pixelSize: 13
                            }
                            ImageButtonType {
                                implicitWidth: 32
                                implicitHeight: 32
                                hoverEnabled: true
                                image: "qrc:/images/controls/copy.svg"
                                imageColor: AmneziaStyle.color.mutedGray
                                onClicked: { GC.copyToClipBoard(modelData)
                                    PageController.showNotificationMessage(qsTr("Copied")) }
                            }
                            ImageButtonType {
                                implicitWidth: 32
                                implicitHeight: 32
                                hoverEnabled: true
                                image: "qrc:/images/controls/trash.svg"
                                imageColor: AmneziaStyle.color.vibrantRed
                                onClicked: {
                                    MtProxyConfigModel.removeAdditionalSecret(index)
                                    InstallController.updateContainer(MtProxyConfigModel.getConfig(), false)
                                    InstallController.restartContainer(MtProxyConfigModel.getConfig())
                                }
                            }
                        }
                    }

                    BasicButtonType {
                        Layout.fillWidth: true
                        Layout.topMargin: 8

                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        Layout.bottomMargin: 16
                        text: qsTr("Add additional secret")
                        clickedFunc: function () {
                            MtProxyConfigModel.addAdditionalSecret()
                            InstallController.updateContainer(MtProxyConfigModel.getConfig(), false)
                            InstallController.restartContainer(MtProxyConfigModel.getConfig())
                        }
                    }

                    // Workers
                    DividerType {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 8
                    }

                    LabelTextType {
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.bottomMargin: 4
                        text: qsTr("Worker mode")
                    }

                    ButtonGroup {
                        id: workerModeGroup
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        Layout.bottomMargin: 4
                        spacing: 0
                        visible: transportMode !== "faketls"

                        HorizontalRadioButton {
                            Layout.fillWidth: true
                            text: qsTr("Auto")
                            ButtonGroup.group: workerModeGroup
                            checked: workersMode === "auto"
                            onClicked: workersMode = "auto"
                        }
                        HorizontalRadioButton {
                            Layout.fillWidth: true
                            text: qsTr("Manual")
                            ButtonGroup.group: workerModeGroup
                            checked: workersMode === "manual"
                            onClicked: workersMode = "manual"
                        }
                    }

                    CaptionTextType {
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        Layout.bottomMargin: 8
                        visible: transportMode === "faketls"
                        text: qsTr("Workers are set to 0 automatically for FakeTLS mode.")
                        color: AmneziaStyle.color.mutedGray
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                    }

                    TextFieldWithHeaderType {
                        id: workersTextField
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        Layout.bottomMargin: 16
                        visible: workersMode === "manual" && transportMode !== "faketls"
                        headerText: qsTr("Workers count")
                        textField.placeholderText: "2"
                        textField.text: workers
                        textField.maximumLength: 3
                        textField.validator: IntValidator {
                            bottom: 1
                            top: 999
                        }
                        textField.onEditingFinished: {
                            textField.text = textField.text.replace(/^\s+|\s+$/g, '')
                            if (textField.text !== workers) {
                                workers = textField.text
                            }
                        }
                    }

                    // NAT settings
                    DividerType {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 8
                    }

                    SwitcherType {
                        Layout.fillWidth: true
                        Layout.rightMargin: 16
                        Layout.leftMargin: 16
                        Layout.bottomMargin: 4
                        text: qsTr("Server is behind NAT / Docker bridge")
                        descriptionText: qsTr("Enable if your server is not directly accessible from the internet, e.g. Docker or private network")
                        checked: natEnabled
                        onToggled: function () {
                            if (checked !== natEnabled) natEnabled = checked
                        }
                    }

                    TextFieldWithHeaderType {
                        id: natInternalIpTextField
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        Layout.bottomMargin: 16
                        visible: natEnabled
                        headerText: qsTr("Internal IP")
                        textField.placeholderText: "172.17.0.2"
                        textField.text: natInternalIp
                        textField.onEditingFinished: {
                            textField.text = textField.text.replace(/^\s+|\s+$/g, '')
                            if (textField.text !== natInternalIp) {
                                natInternalIp = textField.text
                            }
                        }
                    }

                    TextFieldWithHeaderType {
                        id: natExternalIpTextField
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        Layout.bottomMargin: 16
                        visible: natEnabled
                        headerText: qsTr("External IP")
                        textField.placeholderText: "1.2.3.4"
                        textField.text: natExternalIp
                        textField.onEditingFinished: {
                            textField.text = textField.text.replace(/^\s+|\s+$/g, '')
                            if (textField.text !== natExternalIp) {
                                natExternalIp = textField.text
                            }
                        }
                    }
                }

                // ── Line ──────────────────────────────────────────────────
                DividerType {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                }

                // ── Diagnostics ───────────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 16
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.bottomMargin: 8
                    spacing: 8
                    visible: containerStatus === 1

                    RowLayout {
                        Layout.fillWidth: true

                        Header2Type {
                            Layout.fillWidth: true
                            headerText: qsTr("Diagnostics")
                        }

                        ImageButtonType {
                            implicitWidth: 32; implicitHeight: 32
                            image: "qrc:/images/controls/refresh-cw.svg"
                            imageColor: diagLoading ? AmneziaStyle.color.mutedGray : AmneziaStyle.color.paleGray
                            hoverEnabled: !diagLoading
                            enabled: !diagLoading
                            onClicked: {
                                diagLoading = true
                                InstallController.refreshMtProxyDiagnostics(parseInt(port))
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Rectangle {
                            width: 8; height: 8; radius: 4; color: diagClientsConnected >= 0 ? (diagPortReachable ? AmneziaStyle.color.paleGray : AmneziaStyle.color.vibrantRed) : AmneziaStyle.color.mutedGray
                        }
                        CaptionTextType {
                            Layout.fillWidth: true; text: qsTr("Public port reachable"); color: AmneziaStyle.color.paleGray
                        }
                        CaptionTextType {
                            text: diagClientsConnected < 0 ? qsTr("—") : (diagPortReachable ? qsTr("Yes") : qsTr("No"))
                            color: diagClientsConnected >= 0 ? (diagPortReachable ? AmneziaStyle.color.paleGray : AmneziaStyle.color.vibrantRed) : AmneziaStyle.color.mutedGray
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Rectangle {
                            width: 8; height: 8; radius: 4; color: diagClientsConnected >= 0 ? (diagTelegramReachable ? AmneziaStyle.color.paleGray : AmneziaStyle.color.vibrantRed) : AmneziaStyle.color.mutedGray
                        }
                        CaptionTextType {
                            Layout.fillWidth: true; text: qsTr("Telegram upstream reachable"); color: AmneziaStyle.color.paleGray
                        }
                        CaptionTextType {
                            text: diagClientsConnected < 0 ? qsTr("—") : (diagTelegramReachable ? qsTr("Yes") : qsTr("No"))
                            color: diagClientsConnected >= 0 ? (diagTelegramReachable ? AmneziaStyle.color.paleGray : AmneziaStyle.color.vibrantRed) : AmneziaStyle.color.mutedGray
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Rectangle {
                            width: 8; height: 8; radius: 4; color: diagClientsConnected >= 0 ? AmneziaStyle.color.goldenApricot : AmneziaStyle.color.mutedGray
                        }
                        CaptionTextType {
                            Layout.fillWidth: true; text: qsTr("Clients connected"); color: AmneziaStyle.color.paleGray
                        }
                        CaptionTextType {
                            text: diagClientsConnected < 0 ? qsTr("—") : diagClientsConnected.toString()
                            color: AmneziaStyle.color.paleGray
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Rectangle {
                            width: 8; height: 8; radius: 4; color: AmneziaStyle.color.mutedGray
                        }
                        CaptionTextType {
                            Layout.fillWidth: true; text: qsTr("Last config refresh"); color: AmneziaStyle.color.paleGray
                        }
                        CaptionTextType {
                            text: diagLastConfigRefresh !== "" ? diagLastConfigRefresh : qsTr("—")
                            color: AmneziaStyle.color.mutedGray
                        }
                    }

                    LabelWithButtonType {
                        Layout.fillWidth: true
                        Layout.leftMargin: -16
                        visible: diagStatsEndpoint !== ""
                        text: qsTr("Stats endpoint")
                        descriptionText: diagStatsEndpoint
                        descriptionOnTop: true
                        rightImageSource: "qrc:/images/controls/copy.svg"
                        rightImageColor: AmneziaStyle.color.paleGray
                        clickedFunction: function () {
                            GC.copyToClipBoard(diagStatsEndpoint)
                            PageController.showNotificationMessage(qsTr("Copied"))
                        }
                    }

                    CaptionTextType {
                        Layout.fillWidth: true
                        text: diagLoading ? qsTr("Refreshing…") : qsTr("Tap ↻ to refresh diagnostics")
                        color: AmneziaStyle.color.mutedGray
                        visible: diagClientsConnected < 0
                    }
                }

                // ── Warning ───────────────────────────────────────────────
                CaptionTextType {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.topMargin: 16 * 2
                    Layout.bottomMargin: 24
                    text: qsTr("If you change the settings, the proxy connection link will change. The old link will stop working.")
                    color: AmneziaStyle.color.mutedGray
                    wrapMode: Text.WordWrap
                    font.pixelSize: 12
                }

                // ── Save ──────────────────────────────────────────────────
                BasicButtonType {
                    Layout.fillWidth: true
                    Layout.topMargin: 16
                    Layout.bottomMargin: 32
                    Layout.rightMargin: 16
                    Layout.leftMargin: 16
                    visible: ServersModel.isProcessedServerHasWriteAccess()
                    text: qsTr("Save")
                    clickedFunc: function () {
                        if (!portTextField.textField.acceptableInput) {
                            portTextField.errorText = qsTr("The port must be in the range of 1 to 65535")
                            return
                        }
                        previousPort = port
                        previousTag = tag
                        previousPublicHost = publicHost
                        previousTransportMode = transportMode
                        previousTlsDomain = tlsDomain
                        previousWorkersMode = workersMode
                        previousWorkers = workers
                        previousNatEnabled = natEnabled
                        previousNatInternalIp = natInternalIp
                        previousNatExternalIp = natExternalIp
                        isUpdating = true
                        InstallController.updateContainer(MtProxyConfigModel.getConfig(), false)
                        InstallController.restartContainer(MtProxyConfigModel.getConfig())
                    }
                }
            }
        }
    }

    // ── QR overlay ────────────────────────────────────────────────────────────

    // ==========================================================================
    // Вариант 2: DrawerType2 (выезжает снизу) — раскомментировать для использования,
    // и закомментировать Вариант 1 ниже и onClicked выше
    // ==========================================================================
    /*
    DrawerType2 {
        id: qrDrawer
        parent: root
        anchors.fill: parent
        expandedHeight: root.height * 0.9

        property string qrSource: ""
        property string linkUrl: ""

        expandedStateContent: ColumnLayout {
            width: qrDrawer.width
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 16
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                Header2Type {
                    Layout.fillWidth: true
                    headerText: qsTr("Telegram connection link")
                }
                ImageButtonType {
                    implicitWidth: 36
 implicitHeight: 36
                    hoverEnabled: true
                    image: "qrc:/images/controls/close.svg"
                    imageColor: AmneziaStyle.color.paleGray
                    onClicked: qrDrawer.closeTriggered()
                }
            }

            BasicButtonType {
                Layout.fillWidth: true
                Layout.topMargin: 24
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                text: qsTr("Share")
                leftImageSource: "qrc:/images/controls/share-2.svg"
                clickedFunc: function () { Qt.openUrlExternally(qrDrawer.linkUrl) }
            }

            BasicButtonType {
                Layout.fillWidth: true
                Layout.topMargin: 12
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                text: qsTr("Copy")
                leftImageSource: "qrc:/images/controls/copy.svg"
                clickedFunc: function () {
                    GC.copyToClipBoard(qrDrawer.linkUrl)
                    PageController.showNotificationMessage(qsTr("Copied"))
                    qrDrawer.closeTriggered()
                }
            }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 24
                width: 220
 height: 220
                color: "white"
                radius: 8
                Image {
                    anchors.fill: parent
                    anchors.margins: 8
                    smooth: false
                    fillMode: Image.PreserveAspectFit
                    source: qrDrawer.qrSource
                }
            }

            CaptionTextType {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 16
                Layout.leftMargin: 32
                Layout.rightMargin: 32
                Layout.bottomMargin: 24
                text: qsTr("Scan with your camera to add proxy to Telegram")
                color: AmneziaStyle.color.mutedGray
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }
    }
    */

    // ==========================================================================
    // Вариант 1: fullscreen overlay (текущий)
    // ==========================================================================

    Rectangle {
        id: qrOverlay
        anchors.fill: parent
        color: AmneziaStyle.color.midnightBlack
        visible: false
        z: 200

        property string qrSource: ""
        property string linkUrl: ""

        // Dim background tap to close
        MouseArea {
            anchors.fill: parent
            onClicked: qrOverlay.visible = false
        }

        // Close button — top right, outside panel
        ImageButtonType {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 20 + SettingsController.safeAreaTopMargin
            anchors.rightMargin: 16
            implicitWidth: 40
            implicitHeight: 40
            hoverEnabled: true
            image: "qrc:/images/controls/close.svg"
            imageColor: AmneziaStyle.color.paleGray
            z: 201
            onClicked: qrOverlay.visible = false
        }

        // Panel
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 60 + SettingsController.safeAreaTopMargin
            implicitHeight: qrPanelContent.implicitHeight
            color: AmneziaStyle.color.onyxBlack
            radius: 16
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 16
                color: AmneziaStyle.color.onyxBlack
            }

            // Prevent tap-through to dim background
            MouseArea {
                anchors.fill: parent
            }

            ColumnLayout {
                id: qrPanelContent
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: 0

                // Title
                Header2Type {
                    Layout.fillWidth: true
                    Layout.topMargin: 24
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    headerText: qsTr("Telegram connection link")
                }

                // Share
                BasicButtonType {
                    Layout.fillWidth: true
                    Layout.topMargin: 24
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    text: qsTr("Share")
                    leftImageSource: "qrc:/images/controls/share-2.svg"
                    clickedFunc: function () {
                        Qt.openUrlExternally(qrOverlay.linkUrl)
                    }
                }

                // Copy
                BasicButtonType {
                    Layout.fillWidth: true
                    Layout.topMargin: 12
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    text: qsTr("Copy")
                    leftImageSource: "qrc:/images/controls/copy.svg"
                    clickedFunc: function () {
                        GC.copyToClipBoard(qrOverlay.linkUrl)
                        PageController.showNotificationMessage(qsTr("Copied"))
                        qrOverlay.visible = false
                    }
                }

                // QR code
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 24
                    width: 220
                    height: 220
                    color: "white"
                    radius: 8

                    Image {
                        anchors.fill: parent
                        anchors.margins: 8
                        smooth: false
                        fillMode: Image.PreserveAspectFit
                        source: qrOverlay.qrSource
                    }
                }

                // Caption
                CaptionTextType {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 16
                    Layout.leftMargin: 32
                    Layout.rightMargin: 32
                    Layout.bottomMargin: 32 + SettingsController.safeAreaBottomMargin
                    text: qsTr("Scan with your camera to add proxy to Telegram")
                    color: AmneziaStyle.color.mutedGray
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    // ── Loading overlay ──────────────────────────────────────────────────────

    Rectangle {
        anchors.top: pageHeader.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        visible: isCheckingStatus || isUpdating
        color: AmneziaStyle.color.midnightBlack
        opacity: 0.6
        MouseArea {
            anchors.fill: parent
        }
        BusyIndicator {
            anchors.centerIn: parent
            running: isCheckingStatus || isUpdating
            width: 48
            height: 48
        }
    }
}
