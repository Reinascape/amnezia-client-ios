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

    // 0 = NotDeployed, 1 = Running, 2 = Stopped, 3 = Error, 4 = Updating
    property int containerStatus: 1
    property bool isUpdating: false
    property bool isCheckingStatus: false
    property bool previousEnabled: true  // for rollback on error
    property int previousContainerStatus: 1  // for rollback on error

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

        function onUpdateContainerFinished() {
            isUpdating = false
            PageController.showNotificationMessage(qsTr("Settings updated successfully"))
        }

        function onInstallationErrorOccurred() {
            // Rollback switch and status to previous state
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
            // Sync switch state with real container status
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

    BackButtonType {
        id: backButton

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 20 + SettingsController.safeAreaTopMargin

        onFocusChanged: {
            if (this.activeFocus) {
                listView.positionViewAtBeginning()
            }
        }
    }

    ListViewType {
        id: listView

        anchors.top: backButton.bottom
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.left: parent.left

        model: MtProxyConfigModel

        delegate: ColumnLayout {
            width: listView.width

            spacing: 0

            BaseHeaderType {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                headerText: qsTr("MTProxy settings")
                descriptionText: qsTr("Telegram MTProto proxy. Share the link below with users to connect through your server.")
            }

            SwitcherType {
                id: enableMtProxySwitch

                Layout.fillWidth: true
                Layout.topMargin: 24
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.bottomMargin: 8

                text: qsTr("Enable MTProxy")
                descriptionText: root.statusText()
                checked: isEnabled

                enabled: !isCheckingStatus && containerStatus !== 0 && containerStatus !== 3 && !isUpdating

                onToggled: function () {
                    if (checked !== isEnabled) {
                        // Save state for rollback on error
                        previousEnabled = isEnabled
                        previousContainerStatus = containerStatus
                        isEnabled = checked
                        isUpdating = true
                        InstallController.setContainerEnabled(ContainerEnum.MtProxy, checked)
                    }
                }
            }

            // Transport mode segmented control
            ButtonGroup {
                id: transportModeGroup
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 16
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.bottomMargin: 0
                spacing: 0

                HorizontalRadioButton {
                    id: standardModeButton
                    Layout.fillWidth: true
                    text: qsTr("Standard")
                    ButtonGroup.group: transportModeGroup
                    checked: transportMode === "standard"
                    onClicked: {
                        if (transportMode !== "standard") {
                            transportMode = "standard"
                        }
                    }
                }

                HorizontalRadioButton {
                    id: fakeTlsModeButton
                    Layout.fillWidth: true
                    text: qsTr("FakeTLS")
                    ButtonGroup.group: transportModeGroup
                    checked: transportMode === "faketls"
                    onClicked: {
                        if (transportMode !== "faketls") {
                            transportMode = "faketls"
                        }
                    }
                }
            }

            // Inline warning — visible only in FakeTLS mode
            WarningType {
                Layout.fillWidth: true
                Layout.topMargin: 12
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.bottomMargin: 0

                visible: transportMode === "faketls"

                iconPath: "qrc:/images/controls/alert-circle.svg"
                imageColor: AmneziaStyle.color.goldenApricot
                textColor: AmneziaStyle.color.goldenApricot
                backGroundColor: AmneziaStyle.color.onyxBlack

                textString: qsTr("FakeTLS is a separate transport mode. Port 443 is recommended. Users with existing Standard connection links will need new FakeTLS links.")
            }

            LabelWithButtonType {
                Layout.fillWidth: true
                Layout.topMargin: 32
                Layout.rightMargin: 16
                Layout.bottomMargin: 16

                text: qsTr("Public host / IP")
                descriptionText: publicHost !== "" ? publicHost : ServersModel.getProcessedServerData("hostName")
                descriptionOnTop: true

                rightImageSource: "qrc:/images/controls/copy.svg"
                rightImageColor: AmneziaStyle.color.paleGray

                clickedFunction: function () {
                    GC.copyToClipBoard(descriptionText)
                    PageController.showNotificationMessage(qsTr("Copied"))
                }
            }

            LabelWithButtonType {
                Layout.fillWidth: true
                Layout.rightMargin: 16
                Layout.bottomMargin: 16

                text: qsTr("Public port")
                descriptionText: port
                descriptionOnTop: true

                rightImageSource: "qrc:/images/controls/copy.svg"
                rightImageColor: AmneziaStyle.color.paleGray

                clickedFunction: function () {
                    GC.copyToClipBoard(descriptionText)
                    PageController.showNotificationMessage(qsTr("Copied"))
                }
            }

            // Base secret block with Generate / Reveal / Copy
            ColumnLayout {
                Layout.fillWidth: true
                Layout.rightMargin: 16
                Layout.bottomMargin: 16
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 0
                    spacing: 0

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        CaptionTextType {
                            text: qsTr("Base secret")
                            color: AmneziaStyle.color.mutedGray
                        }

                        CaptionTextType {
                            id: secretText
                            property bool revealed: false
                            Layout.fillWidth: true
                            text: revealed ? secret : secret.replace(/./g, "•")
                            color: AmneziaStyle.color.paleGray
                            font.pixelSize: 14
                            wrapMode: Text.WrapAnywhere
                        }
                    }

                    // Reveal button
                    ImageButtonType {
                        implicitWidth: 40
                        implicitHeight: 40
                        hoverEnabled: true
                        image: secretText.revealed
                            ? "qrc:/images/controls/eye-off.svg"
                            : "qrc:/images/controls/eye.svg"
                        imageColor: AmneziaStyle.color.paleGray
                        onClicked: secretText.revealed = !secretText.revealed
                    }

                    // Copy button
                    ImageButtonType {
                        implicitWidth: 40
                        implicitHeight: 40
                        hoverEnabled: true
                        image: "qrc:/images/controls/copy.svg"
                        imageColor: AmneziaStyle.color.paleGray
                        onClicked: {
                            GC.copyToClipBoard(secret)
                            PageController.showNotificationMessage(qsTr("Copied"))
                        }
                    }
                }

                // Generate button
                BasicButtonType {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16

                    visible: ServersModel.isProcessedServerHasWriteAccess()

                    text: qsTr("Generate new secret")

                    clickedFunc: function () {
                        var headerText = qsTr("Generate new secret?")
                        var descriptionText = qsTr("All existing connection links will stop working. Users will need new links.")
                        var yesButtonText = qsTr("Generate")
                        var noButtonText = qsTr("Cancel")
                        var yesButtonFunction = function () {
                            MtProxyConfigModel.generateSecret()
                            InstallController.updateContainer(MtProxyConfigModel.getConfig())
                        }
                        showQuestionDrawer(headerText, descriptionText, yesButtonText, noButtonText, yesButtonFunction, function () {
                        })
                    }
                }
            }

            LabelWithButtonType {
                Layout.fillWidth: true
                Layout.rightMargin: 16
                Layout.bottomMargin: 16

                visible: tag !== ""

                text: qsTr("Promoted channel tag")
                descriptionText: tag
                descriptionOnTop: true

                rightImageSource: "qrc:/images/controls/copy.svg"
                rightImageColor: AmneziaStyle.color.paleGray

                clickedFunction: function () {
                    GC.copyToClipBoard(descriptionText)
                    PageController.showNotificationMessage(qsTr("Copied"))
                }
            }

            // Connection details block with tabs: Standard / Padded / FakeTLS
            ColumnLayout {
                id: connDetailsBlock
                Layout.fillWidth: true
                Layout.topMargin: 24
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.bottomMargin: 8
                spacing: 0

                visible: secret !== ""

                // Helper: convert domain string to hex
                function domainToHex(domain) {
                    var hex = ""
                    for (var i = 0; i < domain.length; i++) {
                        var code = domain.charCodeAt(i).toString(16)
                        hex += (code.length < 2 ? "0" : "") + code
                    }
                    return hex
                }

                // Compute secrets for each tab
                function standardSecret() {
                    return secret
                }

                function paddedSecret() {
                    return "dd" + secret
                }

                function fakeTlsSecret() {
                    if (tlsDomain !== "")
                        return "ee" + secret + domainToHex(tlsDomain)
                    return "ee" + secret
                }

                function effectiveHost() {
                    return publicHost !== "" ? publicHost : ServersModel.getProcessedServerData("hostName")
                }

                function buildTgLink(s) {
                    return "tg://proxy?server=" + effectiveHost() + "&port=" + port + "&secret=" + s
                }

                function buildTmeLink(s) {
                    return "https://t.me/proxy?server=" + effectiveHost() + "&port=" + port + "&secret=" + s
                }

                Header2Type {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 12
                    headerText: qsTr("Connection details")
                }

                // Tab selector — Standard mode shows Standard+Padded, FakeTLS mode shows only FakeTLS
                ButtonGroup {
                    id: connTabGroup
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 16
                    spacing: 0

                    HorizontalRadioButton {
                        Layout.fillWidth: true
                        text: qsTr("Standard")
                        ButtonGroup.group: connTabGroup
                        visible: transportMode !== "faketls"
                        checked: connTabBar.currentIndex === 0
                        onClicked: connTabBar.currentIndex = 0
                    }
                    HorizontalRadioButton {
                        Layout.fillWidth: true
                        text: qsTr("Padded")
                        ButtonGroup.group: connTabGroup
                        visible: transportMode !== "faketls"
                        checked: connTabBar.currentIndex === 1
                        onClicked: connTabBar.currentIndex = 1
                    }
                    HorizontalRadioButton {
                        Layout.fillWidth: true
                        text: qsTr("FakeTLS")
                        ButtonGroup.group: connTabGroup
                        visible: transportMode === "faketls"
                        checked: connTabBar.currentIndex === 2
                        onClicked: connTabBar.currentIndex = 2
                    }
                }

                // Hidden TabBar to track current index
                TabBar {
                    id: connTabBar
                    visible: false
                    currentIndex: transportMode === "faketls" ? 2 : 0

                    // Reset to correct tab when transport mode changes
                    onCurrentIndexChanged: {
                        if (transportMode === "faketls" && currentIndex !== 2) currentIndex = 2
                        if (transportMode !== "faketls" && currentIndex === 2) currentIndex = 0
                    }
                }

                // Current tab secret
                property string activeSecret: {
                    if (connTabBar.currentIndex === 0) return standardSecret()
                    if (connTabBar.currentIndex === 1) return paddedSecret()
                    return fakeTlsSecret()
                }

                onActiveSecretChanged: {
                    // Reset QR when active secret changes (tab switch)
                    var qrCol = qrSection
                    if (qrCol && qrCol.qrVisible) {
                        qrCol.qrSource = MtProxyConfigModel.generateQrCode(
                            buildTgLink(activeSecret))
                    }
                }

                // Secret row
                RowLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 4
                    spacing: 0

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        CaptionTextType {
                            text: qsTr("Secret")
                            color: AmneziaStyle.color.mutedGray
                        }

                        CaptionTextType {
                            id: connSecretText
                            property bool revealed: false
                            Layout.fillWidth: true
                            text: revealed
                                ? connDetailsBlock.activeSecret
                                : connDetailsBlock.activeSecret.replace(/./g, "•")
                            color: AmneziaStyle.color.paleGray
                            font.pixelSize: 13
                            wrapMode: Text.WrapAnywhere
                        }
                    }

                    ImageButtonType {
                        implicitWidth: 40; implicitHeight: 40
                        hoverEnabled: true
                        image: connSecretText.revealed
                            ? "qrc:/images/controls/eye-off.svg"
                            : "qrc:/images/controls/eye.svg"
                        imageColor: AmneziaStyle.color.paleGray
                        onClicked: connSecretText.revealed = !connSecretText.revealed
                    }

                    ImageButtonType {
                        implicitWidth: 40; implicitHeight: 40
                        hoverEnabled: true
                        image: "qrc:/images/controls/copy.svg"
                        imageColor: AmneziaStyle.color.paleGray
                        onClicked: {
                            GC.copyToClipBoard(connDetailsBlock.activeSecret)
                            PageController.showNotificationMessage(qsTr("Copied"))
                        }
                    }
                }

                // tg:// link
                LabelWithButtonType {
                    Layout.fillWidth: true
                    Layout.leftMargin: -16
                    Layout.rightMargin: 0
                    Layout.bottomMargin: 4

                    text: qsTr("Telegram link (tg://)")
                    descriptionText: connDetailsBlock.buildTgLink(connDetailsBlock.activeSecret)
                    descriptionOnTop: true
                    textColor: AmneziaStyle.color.goldenApricot

                    rightImageSource: "qrc:/images/controls/copy.svg"
                    rightImageColor: AmneziaStyle.color.paleGray

                    clickedFunction: function () {
                        GC.copyToClipBoard(connDetailsBlock.buildTgLink(connDetailsBlock.activeSecret))
                        PageController.showNotificationMessage(qsTr("Copied"))
                    }
                }

                // t.me link
                LabelWithButtonType {
                    Layout.fillWidth: true
                    Layout.leftMargin: -16
                    Layout.rightMargin: 0
                    Layout.bottomMargin: 4

                    text: qsTr("Telegram link (t.me)")
                    descriptionText: connDetailsBlock.buildTmeLink(connDetailsBlock.activeSecret)
                    descriptionOnTop: true
                    textColor: AmneziaStyle.color.goldenApricot

                    rightImageSource: "qrc:/images/controls/copy.svg"
                    rightImageColor: AmneziaStyle.color.paleGray

                    clickedFunction: function () {
                        GC.copyToClipBoard(connDetailsBlock.buildTmeLink(connDetailsBlock.activeSecret))
                        PageController.showNotificationMessage(qsTr("Copied"))
                    }
                }

                // Copy tg:// link button
                BasicButtonType {
                    Layout.fillWidth: true
                    Layout.topMargin: 8

                    text: qsTr("Copy tg:// link")

                    clickedFunc: function () {
                        GC.copyToClipBoard(connDetailsBlock.buildTgLink(connDetailsBlock.activeSecret))
                        PageController.showNotificationMessage(qsTr("Link copied"))
                    }
                }

                // QR code
                ColumnLayout {
                    id: qrSection
                    Layout.fillWidth: true
                    Layout.topMargin: 16
                    spacing: 8

                    property bool qrVisible: false
                    property string qrSource: ""

                    RowLayout {
                        Layout.fillWidth: true

                        CaptionTextType {
                            Layout.fillWidth: true
                            text: qsTr("QR code")
                            color: AmneziaStyle.color.mutedGray
                        }

                        ImageButtonType {
                            implicitWidth: 32
                            implicitHeight: 32
                            hoverEnabled: true
                            image: "qrc:/images/controls/qr-code.svg"
                            imageColor: parent.parent.qrVisible
                                ? AmneziaStyle.color.goldenApricot
                                : AmneziaStyle.color.paleGray
                            onClicked: {
                                var col = parent.parent
                                col.qrVisible = !col.qrVisible
                                if (col.qrVisible) {
                                    col.qrSource = MtProxyConfigModel.generateQrCode(
                                        connDetailsBlock.buildTgLink(connDetailsBlock.activeSecret))
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 200
                        height: 200
                        color: "white"
                        radius: 8
                        visible: parent.qrVisible && parent.qrSource !== ""

                        Image {
                            anchors.fill: parent
                            anchors.margins: 8
                            smooth: false
                            fillMode: Image.PreserveAspectFit
                            source: parent.parent.qrSource
                        }
                    }
                }
            }

            DrawerType2 {
                id: changeSettingsDrawer
                parent: root

                anchors.fill: parent
                expandedHeight: root.height * 0.9

                expandedStateContent: ColumnLayout {
                    property string tempPort: port
                    property string tempTag: tag
                    property string tempPublicHost: publicHost
                    property string tempTransportMode: transportMode
                    property string tempTlsDomain: tlsDomain
                    property string tempWorkersMode: workersMode
                    property string tempWorkers: workers
                    property bool tempNatEnabled: natEnabled
                    property string tempNatInternalIp: natInternalIp
                    property string tempNatExternalIp: natExternalIp

                    width: parent ? parent.width : 0
                    spacing: 0

                    Connections {
                        target: changeSettingsDrawer

                        function onOpened() {
                            tempPort = port
                            tempTag = tag
                            tempPublicHost = publicHost
                            tempTransportMode = transportMode
                            tempTlsDomain = tlsDomain
                            tempWorkersMode = workersMode
                            tempWorkers = workers
                            tempNatEnabled = natEnabled
                            tempNatInternalIp = natInternalIp
                            tempNatExternalIp = natExternalIp
                        }

                        function onClosed() {
                            port = tempPort
                            tag = tempTag
                            publicHost = tempPublicHost
                            transportMode = tempTransportMode
                            tlsDomain = tempTlsDomain
                            workersMode = tempWorkersMode
                            workers = tempWorkers
                            natEnabled = tempNatEnabled
                            natInternalIp = tempNatInternalIp
                            natExternalIp = tempNatExternalIp
                            portTextField.textField.text = port
                            tagTextField.textField.text = tag
                            publicHostTextField.textField.text = publicHost
                            tlsDomainTextField.textField.text = tlsDomain
                            workersTextField.textField.text = workers
                            natInternalIpTextField.textField.text = natInternalIp
                            natExternalIpTextField.textField.text = natExternalIp
                        }
                    }

                    BaseHeaderType {
                        Layout.fillWidth: true
                        Layout.topMargin: 32
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        Layout.bottomMargin: 16

                        headerText: qsTr("MTProxy settings")
                    }

                    TextFieldWithHeaderType {
                        id: publicHostTextField

                        Layout.fillWidth: true
                        Layout.topMargin: 40
                        Layout.rightMargin: 16
                        Layout.leftMargin: 16
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

                    // Transport mode selector in drawer
                    ButtonGroup {
                        id: drawerTransportModeGroup
                    }

                    LabelTextType {
                        Layout.fillWidth: true
                        Layout.topMargin: 16
                        Layout.leftMargin: 16
                        Layout.bottomMargin: 4
                        text: qsTr("Transport mode")
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        spacing: 0

                        HorizontalRadioButton {
                            Layout.fillWidth: true
                            text: qsTr("Standard")
                            ButtonGroup.group: drawerTransportModeGroup
                            checked: transportMode === "standard"
                            onClicked: transportMode = "standard"
                        }

                        HorizontalRadioButton {
                            Layout.fillWidth: true
                            text: qsTr("FakeTLS")
                            ButtonGroup.group: drawerTransportModeGroup
                            checked: transportMode === "faketls"
                            onClicked: transportMode = "faketls"
                        }
                    }

                    TextFieldWithHeaderType {
                        id: tlsDomainTextField

                        Layout.fillWidth: true
                        Layout.topMargin: 16
                        Layout.rightMargin: 16
                        Layout.leftMargin: 16
                        Layout.bottomMargin: 4

                        visible: transportMode === "faketls"

                        headerText: qsTr("TLS camouflage domain")
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
                        }

                        CaptionTextType {
                            Layout.fillWidth: true
                            text: qsTr("⚠ Changing the domain will invalidate all previously issued FakeTLS connection links.")
                            color: AmneziaStyle.color.goldenApricot
                            wrapMode: Text.WordWrap
                        }
                    }

                    TextFieldWithHeaderType {
                        id: portTextField

                        Layout.fillWidth: true
                        Layout.topMargin: 16
                        Layout.rightMargin: 16
                        Layout.leftMargin: 16
                        Layout.bottomMargin: 16

                        headerText: qsTr("Public port")
                        textField.placeholderText: "443"
                        textField.text: port
                        textField.maximumLength: 5
                        textField.validator: IntValidator {
                            bottom: 1; top: 65535
                        }

                        textField.onEditingFinished: {
                            textField.text = textField.text.replace(/^\s+|\s+$/g, '')
                            if (textField.text !== port) {
                                port = textField.text
                            }
                        }
                    }

                    TextFieldWithHeaderType {
                        id: tagTextField

                        Layout.fillWidth: true
                        Layout.topMargin: 16
                        Layout.rightMargin: 16
                        Layout.leftMargin: 16
                        Layout.bottomMargin: 4

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

                    CaptionTextType {
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        Layout.bottomMargin: 16

                        text: qsTr("Get a tag from @MTProxyBot to enable promoted channel and connection statistics.")
                        color: AmneziaStyle.color.mutedGray
                        wrapMode: Text.WordWrap
                    }

                    // Worker mode section
                    LabelTextType {
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.topMargin: 8
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
                        spacing: 0

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

                    // Warning when FakeTLS + manual workers > 0
                    WarningType {
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        Layout.rightMargin: 16
                        Layout.leftMargin: 16
                        Layout.bottomMargin: 4

                        visible: workersMode === "manual"
                            && transportMode === "faketls"
                            && parseInt(workers) > 0

                        iconPath: "qrc:/images/controls/alert-circle.svg"
                        imageColor: AmneziaStyle.color.goldenApricot
                        textColor: AmneziaStyle.color.goldenApricot
                        backGroundColor: AmneziaStyle.color.onyxBlack
                        textString: qsTr("Workers > 0 are not recommended for FakeTLS mode. Set to 0 for best compatibility.")
                    }

                    TextFieldWithHeaderType {
                        id: workersTextField

                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        Layout.rightMargin: 16
                        Layout.leftMargin: 16
                        Layout.bottomMargin: 16

                        visible: workersMode === "manual"

                        headerText: qsTr("Workers count")
                        textField.placeholderText: "2"
                        textField.text: workers
                        textField.maximumLength: 3
                        textField.validator: IntValidator {
                            bottom: 0; top: 999
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
                        Layout.fillWidth: true; Layout.topMargin: 8; Layout.bottomMargin: 8
                    }

                    SwitcherType {
                        id: natSwitch

                        Layout.fillWidth: true
                        Layout.rightMargin: 16
                        Layout.leftMargin: 16
                        Layout.bottomMargin: 4

                        text: qsTr("Server is behind NAT / Docker bridge")
                        descriptionText: qsTr("Enable if auto-detection of external IP fails")
                        checked: natEnabled

                        onToggled: function () {
                            if (checked !== natEnabled) {
                                natEnabled = checked
                            }
                        }
                    }

                    TextFieldWithHeaderType {
                        id: natInternalIpTextField

                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        Layout.rightMargin: 16
                        Layout.leftMargin: 16
                        Layout.bottomMargin: 8

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
                        Layout.topMargin: 0
                        Layout.rightMargin: 16
                        Layout.leftMargin: 16
                        Layout.bottomMargin: 16

                        visible: natEnabled

                        headerText: qsTr("External IP override")
                        textField.placeholderText: "1.2.3.4"
                        textField.text: natExternalIp

                        textField.onEditingFinished: {
                            textField.text = textField.text.replace(/^\s+|\s+$/g, '')
                            if (textField.text !== natExternalIp) {
                                natExternalIp = textField.text
                            }
                        }
                    }

                    BasicButtonType {
                        id: saveButton

                        Layout.fillWidth: true
                        Layout.topMargin: 24
                        Layout.bottomMargin: 24
                        Layout.rightMargin: 16
                        Layout.leftMargin: 16

                        text: qsTr("Change connection settings")

                        clickedFunc: function () {
                            if (!portTextField.textField.acceptableInput) {
                                portTextField.errorText = qsTr("The port must be in the range of 1 to 65535")
                                return
                            }

                            PageController.goToPage(PageEnum.PageSetupWizardInstalling)
                            InstallController.updateContainer(MtProxyConfigModel.getConfig())
                            tempPort = portTextField.textField.text
                            tempTag = tagTextField.textField.text
                            tempPublicHost = publicHostTextField.textField.text
                            tempTransportMode = transportMode
                            tempTlsDomain = tlsDomainTextField.textField.text
                            tempWorkersMode = workersMode
                            tempWorkers = workersTextField.visible ? workersTextField.textField.text : workers
                            tempNatEnabled = natEnabled
                            tempNatInternalIp = natInternalIpTextField.visible ? natInternalIpTextField.textField.text : natInternalIp
                            tempNatExternalIp = natExternalIpTextField.visible ? natExternalIpTextField.textField.text : natExternalIp
                            changeSettingsDrawer.closeTriggered()
                        }
                    }
                }
            }

            // Diagnostics / Monitoring — read-only block
            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 24
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                spacing: 8

                visible: containerStatus === 1

                RowLayout {
                    Layout.fillWidth: true

                    Header2Type {
                        Layout.fillWidth: true
                        headerText: qsTr("Diagnostics")
                    }

                    ImageButtonType {
                        implicitWidth: 32
                        implicitHeight: 32
                        image: "qrc:/images/controls/refresh-cw.svg"
                        imageColor: diagLoading
                            ? AmneziaStyle.color.mutedGray
                            : AmneziaStyle.color.paleGray
                        hoverEnabled: !diagLoading
                        enabled: !diagLoading

                        onClicked: {
                            diagLoading = true
                            InstallController.refreshMtProxyDiagnostics(parseInt(port))
                        }
                    }
                }

                // Port reachable
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        width: 8; height: 8; radius: 4
                        color: diagClientsConnected >= 0
                            ? (diagPortReachable ? AmneziaStyle.color.paleGray : AmneziaStyle.color.vibrantRed)
                            : AmneziaStyle.color.mutedGray
                    }

                    CaptionTextType {
                        Layout.fillWidth: true
                        text: qsTr("Public port reachable")
                        color: AmneziaStyle.color.paleGray
                    }

                    CaptionTextType {
                        text: diagClientsConnected < 0
                            ? qsTr("—")
                            : (diagPortReachable ? qsTr("Yes") : qsTr("No"))
                        color: diagClientsConnected >= 0
                            ? (diagPortReachable ? AmneziaStyle.color.paleGray : AmneziaStyle.color.vibrantRed)
                            : AmneziaStyle.color.mutedGray
                    }
                }

                // Telegram upstream
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        width: 8; height: 8; radius: 4
                        color: diagClientsConnected >= 0
                            ? (diagTelegramReachable ? AmneziaStyle.color.paleGray : AmneziaStyle.color.vibrantRed)
                            : AmneziaStyle.color.mutedGray
                    }

                    CaptionTextType {
                        Layout.fillWidth: true
                        text: qsTr("Telegram upstream reachable")
                        color: AmneziaStyle.color.paleGray
                    }

                    CaptionTextType {
                        text: diagClientsConnected < 0
                            ? qsTr("—")
                            : (diagTelegramReachable ? qsTr("Yes") : qsTr("No"))
                        color: diagClientsConnected >= 0
                            ? (diagTelegramReachable ? AmneziaStyle.color.paleGray : AmneziaStyle.color.vibrantRed)
                            : AmneziaStyle.color.mutedGray
                    }
                }

                // Clients connected
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        width: 8; height: 8; radius: 4
                        color: diagClientsConnected >= 0
                            ? AmneziaStyle.color.goldenApricot
                            : AmneziaStyle.color.mutedGray
                    }

                    CaptionTextType {
                        Layout.fillWidth: true
                        text: qsTr("Clients connected")
                        color: AmneziaStyle.color.paleGray
                    }

                    CaptionTextType {
                        text: diagClientsConnected < 0 ? qsTr("—") : diagClientsConnected.toString()
                        color: AmneziaStyle.color.paleGray
                    }
                }

                // Last config refresh
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        width: 8; height: 8; radius: 4
                        color: diagLastConfigRefresh !== ""
                            ? AmneziaStyle.color.mutedGray
                            : AmneziaStyle.color.mutedGray
                    }

                    CaptionTextType {
                        Layout.fillWidth: true
                        text: qsTr("Last config refresh")
                        color: AmneziaStyle.color.paleGray
                    }

                    CaptionTextType {
                        text: diagLastConfigRefresh !== "" ? diagLastConfigRefresh : qsTr("—")
                        color: AmneziaStyle.color.mutedGray
                    }
                }

                // Stats endpoint
                LabelWithButtonType {
                    Layout.fillWidth: true
                    Layout.leftMargin: -16
                    Layout.rightMargin: 0
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

            // Advanced section — collapsible
            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 16
                spacing: 0

                visible: ServersModel.isProcessedServerHasWriteAccess()

                // Advanced header — tap to expand/collapse
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

                // Additional secrets — visible when expanded
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    visible: advancedHeader.expanded

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
                                image: "qrc:/images/controls/copy.svg"
                                imageColor: AmneziaStyle.color.mutedGray
                                hoverEnabled: true
                                onClicked: {
                                    GC.copyToClipBoard(modelData)
                                    PageController.showNotificationMessage(qsTr("Copied"))
                                }
                            }

                            ImageButtonType {
                                implicitWidth: 32
                                implicitHeight: 32
                                image: "qrc:/images/controls/trash.svg"
                                imageColor: AmneziaStyle.color.vibrantRed
                                hoverEnabled: true
                                onClicked: {
                                    MtProxyConfigModel.removeAdditionalSecret(index)
                                    InstallController.updateContainer(MtProxyConfigModel.getConfig())
                                }
                            }
                        }
                    }

                    BasicButtonType {
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        Layout.bottomMargin: 8

                        text: qsTr("Add additional secret")

                        clickedFunc: function () {
                            MtProxyConfigModel.addAdditionalSecret()
                            InstallController.updateContainer(MtProxyConfigModel.getConfig())
                        }
                    }
                }
            }

            BasicButtonType {
                id: changeSettingsButton

                Layout.fillWidth: true
                Layout.topMargin: 24
                Layout.bottomMargin: 8
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                visible: ServersModel.isProcessedServerHasWriteAccess()

                text: qsTr("Change connection settings")

                clickedFunc: function () {
                    changeSettingsDrawer.openTriggered()
                }
            }

            LabelWithButtonType {
                id: removeButton

                Layout.fillWidth: true
                Layout.topMargin: 8
                Layout.bottomMargin: 24
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                visible: ServersModel.isProcessedServerHasWriteAccess()

                text: qsTr("Remove ") + ContainersModel.getProcessedContainerName()
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
                    var noButtonFunction = function () {
                    }

                    showQuestionDrawer(headerText, descriptionText, yesButtonText, noButtonText, yesButtonFunction, noButtonFunction)
                }

                MouseArea {
                    anchors.fill: removeButton
                    cursorShape: Qt.PointingHandCursor
                    enabled: false
                }
            }

            DividerType {
                visible: ServersModel.isProcessedServerHasWriteAccess()
            }
        }
    }

    // Overlay while checking status or updating — blocks all interaction
    Rectangle {
        anchors.top: backButton.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        visible: isCheckingStatus || isUpdating
        color: AmneziaStyle.color.midnightBlack
        opacity: 0.6

        MouseArea {
            anchors.fill: parent
            // Consume all clicks
        }

        BusyIndicator {
            anchors.centerIn: parent
            running: isCheckingStatus || isUpdating
            width: 48
            height: 48
        }
    }
}
