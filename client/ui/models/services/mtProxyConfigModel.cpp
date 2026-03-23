#include "mtProxyConfigModel.h"

#include <QRegularExpression>

#include "core/qrCodeUtils.h"
#include "protocols/protocols_defs.h"
#include "qrcodegen.hpp"

using namespace amnezia;

MtProxyConfigModel::MtProxyConfigModel(QObject *parent) : QAbstractListModel(parent)
{
}

int MtProxyConfigModel::rowCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent);
    return 1;
}

bool MtProxyConfigModel::setData(const QModelIndex &index, const QVariant &value, int role)
{
    if (!index.isValid() || index.row() != 0) {
        return false;
    }

    switch (role) {
    case Roles::PortRole: {
        m_protocolConfig.insert(config_key::port, value.toString());
        break;
    }
    case Roles::SecretRole: {
        m_protocolConfig.insert(protocols::mtProxy::secretKey, value.toString());
        break;
    }
    case Roles::TagRole: {
        m_protocolConfig.insert(protocols::mtProxy::tagKey, value.toString());
        break;
    }
    case Roles::IsEnabledRole: {
        m_protocolConfig.insert(protocols::mtProxy::isEnabledKey, value.toBool());
        break;
    }
    case Roles::PublicHostRole: {
        m_protocolConfig.insert(protocols::mtProxy::publicHostKey, value.toString());
        break;
    }
    case Roles::TransportModeRole: {
        m_protocolConfig.insert(protocols::mtProxy::transportModeKey, value.toString());
        break;
    }
    case Roles::TlsDomainRole: {
        m_protocolConfig.insert(protocols::mtProxy::tlsDomainKey, value.toString());
        break;
    }
    case Roles::AdditionalSecretsRole: {
        m_protocolConfig.insert(protocols::mtProxy::additionalSecretsKey,
                                QJsonArray::fromStringList(value.toStringList()));
        break;
    }
    case Roles::WorkersModeRole: {
        m_protocolConfig.insert(protocols::mtProxy::workersModeKey, value.toString());
        break;
    }
    case Roles::WorkersRole: {
        m_protocolConfig.insert(protocols::mtProxy::workersKey, value.toString());
        break;
    }
    case Roles::NatEnabledRole: {
        m_protocolConfig.insert(protocols::mtProxy::natEnabledKey, value.toBool());
        break;
    }
    case Roles::NatInternalIpRole: {
        m_protocolConfig.insert(protocols::mtProxy::natInternalIpKey, value.toString());
        break;
    }
    case Roles::NatExternalIpRole: {
        m_protocolConfig.insert(protocols::mtProxy::natExternalIpKey, value.toString());
        break;
    }
    default: {
        return false;
    }
    }

    emit dataChanged(index, index, QList { role });
    return true;
}

QVariant MtProxyConfigModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() != 0) {
        return QVariant();
    }

    switch (role) {
    case Roles::PortRole: {
        return m_protocolConfig.value(config_key::port).toString(protocols::mtProxy::defaultPort);
    }
    case Roles::SecretRole: {
        return m_protocolConfig.value(protocols::mtProxy::secretKey).toString();
    }
    case Roles::TagRole: {
        return m_protocolConfig.value(protocols::mtProxy::tagKey).toString();
    }
    case Roles::TgLinkRole: {
        return m_protocolConfig.value(protocols::mtProxy::tgLinkKey).toString();
    }
    case Roles::TmeLinkRole: {
        return m_protocolConfig.value(protocols::mtProxy::tmeLinkKey).toString();
    }
    case Roles::IsEnabledRole: {
        return m_protocolConfig.value(protocols::mtProxy::isEnabledKey).toBool(true);
    }
    case Roles::PublicHostRole: {
        return m_protocolConfig.value(protocols::mtProxy::publicHostKey)
                .toString(m_fullConfig.value(config_key::hostName).toString());
    }
    case Roles::TransportModeRole: {
        return m_protocolConfig.value(protocols::mtProxy::transportModeKey)
                .toString(protocols::mtProxy::transportModeStandard);
    }
    case Roles::TlsDomainRole: {
        return m_protocolConfig.value(protocols::mtProxy::tlsDomainKey).toString(protocols::mtProxy::defaultTlsDomain);
    }
    case Roles::AdditionalSecretsRole: {
        QJsonArray arr = m_protocolConfig.value(protocols::mtProxy::additionalSecretsKey).toArray();
        QStringList list;
        for (const auto &v : arr) {
            list << v.toString();
        }
        return list;
    }
    case Roles::WorkersModeRole: {
        return m_protocolConfig.value(protocols::mtProxy::workersModeKey).toString(protocols::mtProxy::workersModeAuto);
    }
    case Roles::WorkersRole: {
        return m_protocolConfig.value(protocols::mtProxy::workersKey).toString(protocols::mtProxy::defaultWorkers);
    }
    case Roles::NatEnabledRole: {
        return m_protocolConfig.value(protocols::mtProxy::natEnabledKey).toBool(false);
    }
    case Roles::NatInternalIpRole: {
        return m_protocolConfig.value(protocols::mtProxy::natInternalIpKey).toString();
    }
    case Roles::NatExternalIpRole: {
        return m_protocolConfig.value(protocols::mtProxy::natExternalIpKey).toString();
    }
    }

    return QVariant();
}

void MtProxyConfigModel::updateModel(const QJsonObject &config)
{
    beginResetModel();

    m_fullConfig = config;
    QJsonObject protocolConfig = config.value(config_key::mtproxy).toObject();

    m_protocolConfig.insert(config_key::port,
                            protocolConfig.value(config_key::port).toString(protocols::mtProxy::defaultPort));
    m_protocolConfig.insert(protocols::mtProxy::secretKey,
                            protocolConfig.value(protocols::mtProxy::secretKey).toString());
    m_protocolConfig.insert(protocols::mtProxy::tagKey, protocolConfig.value(protocols::mtProxy::tagKey).toString());
    m_protocolConfig.insert(protocols::mtProxy::tgLinkKey,
                            protocolConfig.value(protocols::mtProxy::tgLinkKey).toString());
    m_protocolConfig.insert(protocols::mtProxy::tmeLinkKey,
                            protocolConfig.value(protocols::mtProxy::tmeLinkKey).toString());
    m_protocolConfig.insert(protocols::mtProxy::isEnabledKey,
                            protocolConfig.value(protocols::mtProxy::isEnabledKey).toBool(true));
    m_protocolConfig.insert(protocols::mtProxy::publicHostKey,
                            protocolConfig.value(protocols::mtProxy::publicHostKey).toString());
    m_protocolConfig.insert(
            protocols::mtProxy::transportModeKey,
            protocolConfig.value(protocols::mtProxy::transportModeKey).toString(protocols::mtProxy::transportModeStandard));
    m_protocolConfig.insert(protocols::mtProxy::tlsDomainKey,
                            protocolConfig.value(protocols::mtProxy::tlsDomainKey).toString());
    m_protocolConfig.insert(protocols::mtProxy::additionalSecretsKey,
                            protocolConfig.value(protocols::mtProxy::additionalSecretsKey).toArray());
    m_protocolConfig.insert(
            protocols::mtProxy::workersModeKey,
            protocolConfig.value(protocols::mtProxy::workersModeKey).toString(protocols::mtProxy::workersModeAuto));
    m_protocolConfig.insert(
            protocols::mtProxy::workersKey,
            protocolConfig.value(protocols::mtProxy::workersKey).toString(protocols::mtProxy::defaultWorkers));
    m_protocolConfig.insert(protocols::mtProxy::natEnabledKey,
                            protocolConfig.value(protocols::mtProxy::natEnabledKey).toBool(false));
    m_protocolConfig.insert(protocols::mtProxy::natInternalIpKey,
                            protocolConfig.value(protocols::mtProxy::natInternalIpKey).toString());
    m_protocolConfig.insert(protocols::mtProxy::natExternalIpKey,
                            protocolConfig.value(protocols::mtProxy::natExternalIpKey).toString());

    endResetModel();
}

QJsonObject MtProxyConfigModel::getConfig()
{
    m_fullConfig.insert(config_key::mtproxy, m_protocolConfig);
    return m_fullConfig;
}

void MtProxyConfigModel::generateSecret()
{
    // Generate 16 random bytes = 32 hex chars
    QString secret;
    for (int i = 0; i < 16; ++i) {
        quint32 byte = QRandomGenerator::global()->bounded(256);
        secret += QString("%1").arg(byte, 2, 16, QChar('0'));
    }

    m_protocolConfig.insert(protocols::mtProxy::secretKey, secret);
    emit dataChanged(index(0), index(0), QList<int> { SecretRole });
}

void MtProxyConfigModel::setSecret(const QString &secret)
{
    if (secret.isEmpty()) {
        return;
    }
    setData(index(0), secret, SecretRole);
}

bool MtProxyConfigModel::validateAndSetSecret(const QString &rawSecret)
{
    // Validate: must be exactly 32 hex chars
    if (!QRegularExpression("^[0-9a-fA-F]{32}$").match(rawSecret).hasMatch()) {
        return false;
    }
    setData(index(0), rawSecret, SecretRole);
    return true;
}

void MtProxyConfigModel::setPort(const QString &port)
{
    setData(index(0), port, PortRole);
}

void MtProxyConfigModel::setTag(const QString &tag)
{
    setData(index(0), tag, TagRole);
}

void MtProxyConfigModel::setPublicHost(const QString &host)
{
    setData(index(0), host, PublicHostRole);
}

void MtProxyConfigModel::setTransportMode(const QString &mode)
{
    setData(index(0), mode, TransportModeRole);
}

QString MtProxyConfigModel::getTransportMode() const
{
    return m_protocolConfig.value(protocols::mtProxy::transportModeKey).toString(protocols::mtProxy::transportModeStandard);
}

QString MtProxyConfigModel::getTlsDomain() const
{
    return m_protocolConfig.value(protocols::mtProxy::tlsDomainKey).toString(protocols::mtProxy::defaultTlsDomain);
}

QString MtProxyConfigModel::getPublicHost() const
{
    return m_protocolConfig.value(protocols::mtProxy::publicHostKey).toString();
}

void MtProxyConfigModel::setTlsDomain(const QString &domain)
{
    setData(index(0), domain, TlsDomainRole);
}

void MtProxyConfigModel::setWorkersMode(const QString &mode)
{
    setData(index(0), mode, WorkersModeRole);
}

void MtProxyConfigModel::setWorkers(const QString &workers)
{
    setData(index(0), workers, WorkersRole);
}

void MtProxyConfigModel::setNatEnabled(bool enabled)
{
    setData(index(0), enabled, NatEnabledRole);
}

void MtProxyConfigModel::setNatInternalIp(const QString &ip)
{
    setData(index(0), ip, NatInternalIpRole);
}

void MtProxyConfigModel::setNatExternalIp(const QString &ip)
{
    setData(index(0), ip, NatExternalIpRole);
}

void MtProxyConfigModel::addAdditionalSecret()
{
    QString newSecret;
    for (int i = 0; i < 16; ++i) {
        quint32 byte = QRandomGenerator::global()->bounded(256);
        newSecret += QString("%1").arg(byte, 2, 16, QChar('0'));
    }

    QJsonArray arr = m_protocolConfig.value(protocols::mtProxy::additionalSecretsKey).toArray();
    arr.append(newSecret);
    m_protocolConfig.insert(protocols::mtProxy::additionalSecretsKey, arr);
    emit dataChanged(index(0), index(0), QList<int> { AdditionalSecretsRole });
}

void MtProxyConfigModel::removeAdditionalSecret(int idx)
{
    QJsonArray arr = m_protocolConfig.value(protocols::mtProxy::additionalSecretsKey).toArray();
    if (idx < 0 || idx >= arr.size()) {
        return;
    }
    arr.removeAt(idx);
    m_protocolConfig.insert(protocols::mtProxy::additionalSecretsKey, arr);
    emit dataChanged(index(0), index(0), QList<int> { AdditionalSecretsRole });
}

void MtProxyConfigModel::setEnabled(bool enabled)
{
    m_protocolConfig.insert(protocols::mtProxy::isEnabledKey, enabled);
    emit dataChanged(index(0), index(0), QList<int> { IsEnabledRole });
}

QString MtProxyConfigModel::generateQrCode(const QString &text)
{
    if (text.isEmpty()) {
        return "";
    }
    auto qr = qrCodeUtils::generateQrCode(text.toUtf8());
    return qrCodeUtils::svgToBase64(QString::fromStdString(toSvgString(qr, 1)));
}

QString MtProxyConfigModel::defaultTlsDomain() const
{
    return protocols::mtProxy::defaultTlsDomain;
}

QString MtProxyConfigModel::defaultPort() const
{
    return protocols::mtProxy::defaultPort;
}

QString MtProxyConfigModel::defaultWorkers() const
{
    return protocols::mtProxy::defaultWorkers;
}

int MtProxyConfigModel::maxWorkers() const
{
    return protocols::mtProxy::maxWorkers;
}

QString MtProxyConfigModel::transportModeStandard() const
{
    return protocols::mtProxy::transportModeStandard;
}

QString MtProxyConfigModel::transportModeFakeTLS() const
{
    return protocols::mtProxy::transportModeFakeTLS;
}

QString MtProxyConfigModel::workersModeAuto() const
{
    return protocols::mtProxy::workersModeAuto;
}

QString MtProxyConfigModel::workersModeManual() const
{
    return protocols::mtProxy::workersModeManual;
}

QHash<int, QByteArray> MtProxyConfigModel::roleNames() const
{
    QHash<int, QByteArray> roles;

    roles[PortRole] = "port";
    roles[SecretRole] = "secret";
    roles[TagRole] = "tag";
    roles[TgLinkRole] = "tgLink";
    roles[TmeLinkRole] = "tmeLink";
    roles[IsEnabledRole] = "isEnabled";
    roles[PublicHostRole] = "publicHost";
    roles[TransportModeRole] = "transportMode";
    roles[TlsDomainRole] = "tlsDomain";
    roles[AdditionalSecretsRole] = "additionalSecrets";
    roles[WorkersModeRole] = "workersMode";
    roles[WorkersRole] = "workers";
    roles[NatEnabledRole] = "natEnabled";
    roles[NatInternalIpRole] = "natInternalIp";
    roles[NatExternalIpRole] = "natExternalIp";

    return roles;
}
