# リージョン間の VPC ピアリング接続経由で SES SMTP の VPC endpoint を使う素振り

下記によると Amazon SES の SMTP エンドポイントに VPC エンドポイント（Private Link）経由でアクセスできるようになったので、インターネットアクセスの無いプライベートサブネットからでも VPC エンドポイント経由で SMTP でメールを送れるようになったようです。

> - https://aws.amazon.com/jp/blogs/aws/new-amazon-simple-email-service-ses-for-vpc-endpoints/
> - https://aws.amazon.com/jp/about-aws/whats-new/2020/04/amazon-ses-now-offers-vpc-endpoint-support-for-smtp-endpoints/

もうこれでプライベートサブネットに配置した EC2 インスタンスからメールを送るためだけに NAT ゲートウェイを作る必要はなくなりました。

ただ、相変わらず SES は東京リージョンでは利用できず、SMTP の VPC エンドポイントも東京リージョンには作成できないため、東京リージョンの VPC と SES が利用可能なリージョン（オレゴン）の VPC をピアリング接続し、リージョン間 VPC ピアリング接続を経由して SES SMTP のエンドポイントを使ってみました。

環境は Terraform で作りました。[残骸はこちら](https://github.com/ngyuki-sandbox/aws-ses-private-link-via-peering)。

bastion インスタンスやそもそも Internet Gateway すら作っていませんが、SSM Session Manager でログインできるので `session-manager-plugin` のインストールや `~/.ssh/config` の設定が終わっていれば下記のようにインスタンス ID でログインできます。

```sh
env AWS_REGION=us-west-2      ssh i-xxxxxxxxxxxxxxxxx
env AWS_REGION=ap-northeast-1 ssh i-xxxxxxxxxxxxxxxxx
```

## オレゴン(us-west-2)のインスタンスからメール送信

まずはオレゴン(us-west-2)のインスタンスに SSH ログインし、VPC エンドポイントにアクセスしてみます。

```sh
dig email-smtp.us-west-2.amazonaws.com
#=> email-smtp.us-west-2.amazonaws.com. 60 IN A     10.200.100.121

curl telnet://email-smtp.us-west-2.amazonaws.com:587
#=> 220 email-smtp.amazonaws.com ESMTP SimpleEmailService-d-xxxxxxxxx xxxxxxxxxxxxxxxxxxxx
```

名前解決の結果がプライベートアドレスになっており、587 ポートへの接続も成功しました。

postfix を設定してメールを送ってみます。

```sh
sudo postconf -e "relayhost = [email-smtp.us-west-2.amazonaws.com]:587" \
"smtp_sasl_auth_enable = yes" \
"smtp_sasl_security_options = noanonymous" \
"smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd" \
"smtp_use_tls = yes" \
"smtp_tls_security_level = encrypt" \
"smtp_tls_note_starttls_offer = yes"

# $SMTP_USERNAME と $SMTP_PASSWORD には SMTP のクレデンシャルが入っています
echo "[email-smtp.us-west-2.amazonaws.com]:587 $SMTP_USERNAME:$SMTP_PASSWORD" |
  sudo tee /etc/postfix/sasl_passwd >/dev/null

sudo postmap hash:/etc/postfix/sasl_passwd
sudo chown root:root /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db
sudo chmod 0600 /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db
sudo systemctl restart postfix

sendmail -t -foreore@example.com <<EOS
To: oreore@example.com
From: oreore@example.com
Subject: this is test

this is test
.
EOS

sudo tail -f /var/log/maillog
```

送信したメールが受信できることを確認しました。このインスタンスはインターネットアクセスが不可能で、`yum update` も素のままではできませんが、VPC エンドポイント経由でメールを送ることができました。

## 東京(ap-northeast-1)のインスタンスからメール送信

次に東京(ap-northeast-1)のインスタンスに SSH ログインし、VPC エンドポイントにアクセスしてみます。

```sh
dig email-smtp.us-west-2.amazonaws.com
#=> email-smtp.us-west-2.amazonaws.com. 60 IN A     52.40.152.63
#=> email-smtp.us-west-2.amazonaws.com. 60 IN A     52.32.157.220
#=> email-smtp.us-west-2.amazonaws.com. 60 IN A     34.214.66.156
#=> email-smtp.us-west-2.amazonaws.com. 60 IN A     44.233.4.146
#=> email-smtp.us-west-2.amazonaws.com. 60 IN A     35.160.245.254
#=> email-smtp.us-west-2.amazonaws.com. 60 IN A     35.161.82.107
```

名前解決の結果がパブリックアドレスになってしまいました。

VPC エンドポイントで **Private DNS names enabled** は有効にしているし、ピアリング接続で **DNS resolution from accepter VPC to private IP** も **DNS resolution from requester VPC to private IP** も有効になっているのですが、ピアリング接続の先の VPC エンドポイントの Private DNS name の名前解決はできないようです。

次のように VPC エンドポイント固有の DNS 名を使えばプライベートアドレスが返ってきました。

```sh
dig vpce-xxxxxxxxxxxxxxxxx-xxxxxxxx.email-smtp.us-west-2.vpce.amazonaws.com
#=> vpce-xxxxxxxxxxxxxxxxx-xxxxxxxx.email-smtp.us-west-2.vpce.amazonaws.com. 60 IN A 10.200.100.121

curl telnet://vpce-xxxxxxxxxxxxxxxxx-xxxxxxxx.email-smtp.us-west-2.vpce.amazonaws.com:587
#=> 220 email-smtp.amazonaws.com ESMTP SimpleEmailService-d-xxxxxxxxx xxxxxxxxxxxxxxxxxxxx
```

名前解決の結果がプライベートアドレスになっており、587 ポートへの接続も成功しました。

ただ、こんなホスト名では TLS でホスト名の検証が通らないのではと思ったのですが、

```sh
openssl s_client -starttls smtp \
    -connect vpce-xxxxxxxxxxxxxxxxx-xxxxxxxx.email-smtp.us-west-2.vpce.amazonaws.com:587 \
    2>/dev/null \
  | openssl x509 -noout -text \
  | grep -A1 'X509v3 Subject Alternative Name'
#=> X509v3 Subject Alternative Name:
#=>   DNS:email-smtp-fips.us-west-2.amazonaws.com, DNS:*.email-smtp.us-west-2.vpce.amazonaws.com, DNS:email-smtp.us-west-2.amazonaws.com
```

SANs で `DNS:*.email-smtp.us-west-2.vpce.amazonaws.com` があるので大丈夫なようです。

postfix を設定してメールを送ってみます。 `email-smtp.us-west-2.amazonaws.com` だとダメなので `vpce` から始まる VPC エンドポイント固有の DNS 名を使う必要があります(`$SMTP_HOSTNAME` 環境変数に入れてます)。

```sh
sudo postconf -e "relayhost = [$SMTP_HOSTNAME]:587" \
"smtp_sasl_auth_enable = yes" \
"smtp_sasl_security_options = noanonymous" \
"smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd" \
"smtp_use_tls = yes" \
"smtp_tls_security_level = encrypt" \
"smtp_tls_note_starttls_offer = yes"

echo "[$SMTP_HOSTNAME]:587 $SMTP_USERNAME:$SMTP_PASSWORD" |
  sudo tee /etc/postfix/sasl_passwd >/dev/null

sudo postmap hash:/etc/postfix/sasl_passwd
sudo chown root:root /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db
sudo chmod 0600 /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db
sudo systemctl restart postfix

sendmail -t -foreore@example.com <<EOS
To: oreore@example.com
From: oreore@example.com
Subject: this is test

this is test
.
EOS

sudo tail -f /var/log/maillog
```

送信したメールが受信できることを確認しました。このインスタンスはインターネットアクセスが不可能で、しかも SES が利用できない東京リージョンですが、ピアリング接続経由の VPC エンドポイント経由でメールを送ることができました。

## さいごに

主要なサービスはだいたい VPC エンドポイントが作れるようになったし、SSH も SSM の VPC エンドポイントがあればプライベートサブネットでも直に接続できるので、もう踏み台や NAT は不要そうです。
