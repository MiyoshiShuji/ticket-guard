# ticket-guard

[![CI](https://github.com/MiyoshiShuji/ticket-guard/workflows/ci/badge.svg)](https://github.com/MiyoshiShuji/ticket-guard/actions/workflows/ci.yml)
[![Deploy](https://github.com/MiyoshiShuji/ticket-guard/workflows/Deploy%20to%20Azure/badge.svg)](https://github.com/MiyoshiShuji/ticket-guard/actions/workflows/deploy.yml)

## /api/issue-token (Azure Function)

HTTP POST `https://<your-function-app>.azurewebsites.net/api/issue-token?code=<function_key>`

リクエスト JSON ボディ:

```
{
	"ticketId": "string (required)",
	"deviceId": "string (required)",
	"ttl": 8   // optional seconds, clamped to 5..30, default 8
}
```

レスポンス JSON:
```
{
	"ticketId": "...",
	"deviceId": "...",
	"startAtEpochSec": 1700000000,
	"ttlSec": 8,
	"nonce": "base64url",
	"sig": "base64url(hmacSHA256(secret, "ticketId|deviceId|startAt|ttl|nonce"))"
}
```

### 署名の詳細
```
message = f"{ticketId}|{deviceId}|{startAtEpochSec}|{ttlSec}|{nonce}".encode()
sig = base64url( HMAC_SHA256( SIGNING_SECRET, message ) )

禁止文字: `ticketId` / `deviceId` に区切り文字 `|` は使用禁止 (署名メッセージ分解曖昧化防止)
```

### 環境変数
Function App の設定で `SIGNING_SECRET`（強力なランダムシークレット）を設定してください。この値はログには出力されません。

### ローカル開発
```
cd functions
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
func start  # Azure Functions Core Tools がインストールされている場合
```

テスト実行:
```
pytest -q
```

### 注意事項
- TTL が 5 未満の場合は 5 に、30 より大きい場合は 30 に、未指定の場合は 8 になります。
- Nonce は 12 バイトのランダムデータを base64url エンコード（パディングなし）したものです。
- 構造化ログイベント: `validation_failed`、`missing_signing_secret`、`token_issued`

### 検証例 (Python)
```python
import hmac, hashlib, base64

def b64url(data: bytes) -> str:
	return base64.urlsafe_b64encode(data).rstrip(b"=").decode()

def verify(secret: str, ticket_id: str, device_id: str, start_at: int, ttl: int, nonce: str, sig: str) -> bool:
	msg = f"{ticket_id}|{device_id}|{start_at}|{ttl}|{nonce}".encode()
	expected = b64url(hmac.new(secret.encode(), msg, hashlib.sha256).digest())
	# 固定時間比較を推奨 (hmac.compare_digest)
	return hmac.compare_digest(expected, sig)
```

## Azure デプロイメント

### 前提条件

1. **Azure リソース**:
   - Azure サブスクリプション
   - デプロイ用のリソースグループ
   
2. **GitHub OIDC セットアップ**:
   - GitHub Actions 用の連携資格情報を持つサービスプリンシパル
   - 対象リソースグループへの共同作成者アクセス

3. **リポジトリシークレット** (GitHub リポジトリ設定で構成):
   - `AZURE_CLIENT_ID` - サービスプリンシパル クライアント ID
   - `AZURE_TENANT_ID` - Azure テナント ID
   - `AZURE_SUBSCRIPTION_ID` - Azure サブスクリプション ID
   - `AZURE_RESOURCE_GROUP` - 対象リソースグループ名
   - `APP_BASENAME` - リソースのベース名 (例: "ticket-guard")
   - `SIGNING_SECRET` - HMAC 署名用の強力なランダムシークレット

### セットアップガイド

1. **OIDC を使用した Azure サービスプリンシパルの作成**:
```bash
# サービスプリンシパルを作成
az ad sp create-for-rbac --name "github-actions-ticket-guard" \
  --role contributor \
  --scopes /subscriptions/{subscription-id}/resourceGroups/{resource-group-name}

# 出力をメモ: appId (クライアント ID)、tenant
```

2. **連携資格情報の作成**:
```bash
az ad app federated-credential create \
  --id {client-id} \
  --parameters '{
    "name": "github-actions-main",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:MiyoshiShuji/ticket-guard:ref:refs/heads/main",
    "description": "GitHub Actions OIDC for main branch",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

3. **リポジトリシークレットの設定** GitHub Settings > Secrets and variables > Actions で設定

4. **デプロイ**:
   - `main` ブランチにプッシュして自動デプロイをトリガー
   - または Actions タブ > Deploy to Azure > Run workflow で手動トリガー

### インフラストラクチャ

デプロイメントによって以下が作成されます:
- **ストレージアカウント** - Azure Functions ランタイムストレージ
- **Application Insights** - 監視とログ記録
- **App Service プラン** - 従量課金 (サーバーレス) プラン
- **Function App** - Python 3.11 ランタイムとセキュリティ設定

詳細なインフラストラクチャドキュメントについては `infra/README.md` を参照してください。

### Function エンドポイント

デプロイ後、Function は以下で利用可能になります:
```
POST https://{app-name}.azurewebsites.net/api/issue-token?code={function-key}
```

Function キーはデプロイ中に取得され、ワークフローログに表示されます。

