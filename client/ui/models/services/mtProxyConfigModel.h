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
    Q_INVOKABLE void addAdditionalSecret();
    Q_INVOKABLE void removeAdditionalSecret(int idx);
    Q_INVOKABLE QString generateQrCode(const QString &text);
    Q_INVOKABLE void setEnabled(bool enabled);

protected:
    QHash<int, QByteArray> roleNames() const override;

private:
    QJsonObject m_protocolConfig;
    QJsonObject m_fullConfig;
};

#endif // MTPROXYCONFIGMODEL_H
