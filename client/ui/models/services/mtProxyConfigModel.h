#ifndef MTPROXYCONFIGMODEL_H
#define MTPROXYCONFIGMODEL_H

#include <QAbstractListModel>
#include <QJsonArray>
#include <QJsonObject>
#include <QRandomGenerator>

#include "containers/containers_defs.h"
#include "core/qrCodeUtils.h"

class MtProxyConfigModel : public QAbstractListModel
{
    Q_OBJECT

public:
    enum Roles {
        PortRole = Qt::UserRole + 1,
        SecretRole,
        TagRole,
        TgLinkRole,
        TmeLinkRole,
        IsEnabledRole,
        PublicHostRole,
        TransportModeRole,
        TlsDomainRole,
        AdditionalSecretsRole,
        WorkersModeRole,
        WorkersRole,
        NatEnabledRole,
        NatInternalIpRole,
        NatExternalIpRole
    };

    explicit MtProxyConfigModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;

    bool setData(const QModelIndex &index, const QVariant &value, int role) override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;

public slots:
    void updateModel(const QJsonObject &config);
    QJsonObject getConfig();

    Q_INVOKABLE void generateSecret();
    Q_INVOKABLE void setSecret(const QString &secret);
    Q_INVOKABLE bool validateAndSetSecret(const QString &rawSecret);
    Q_INVOKABLE void setPort(const QString &port);
    Q_INVOKABLE void setTag(const QString &tag);
    Q_INVOKABLE void setPublicHost(const QString &host);
    Q_INVOKABLE void setTransportMode(const QString &mode);
    Q_INVOKABLE QString getTransportMode() const;
    Q_INVOKABLE QString getTlsDomain() const;
    Q_INVOKABLE QString getPublicHost() const;
    Q_INVOKABLE void setTlsDomain(const QString &domain);
    Q_INVOKABLE void setWorkersMode(const QString &mode);
    Q_INVOKABLE void setWorkers(const QString &workers);
    Q_INVOKABLE void setNatEnabled(bool enabled);
    Q_INVOKABLE void setNatInternalIp(const QString &ip);
    Q_INVOKABLE void setNatExternalIp(const QString &ip);
    Q_INVOKABLE void addAdditionalSecret();
    Q_INVOKABLE void removeAdditionalSecret(int idx);
    Q_INVOKABLE QString generateQrCode(const QString &text);
    Q_INVOKABLE void setEnabled(bool enabled);

    Q_INVOKABLE QString defaultTlsDomain() const;
    Q_INVOKABLE QString defaultPort() const;
    Q_INVOKABLE QString defaultWorkers() const;
    Q_INVOKABLE int maxWorkers() const;
    Q_INVOKABLE QString transportModeStandard() const;
    Q_INVOKABLE QString transportModeFakeTLS() const;
    Q_INVOKABLE QString workersModeAuto() const;
    Q_INVOKABLE QString workersModeManual() const;

protected:
    QHash<int, QByteArray> roleNames() const override;

private:
    QJsonObject m_protocolConfig;
    QJsonObject m_fullConfig;
};

#endif // MTPROXYCONFIGMODEL_H
