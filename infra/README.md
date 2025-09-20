# Azure Functions Infrastructure (PoC)

`infra/` ディレクトリは 現段階 (Phase 0) では「Resource Group のみ」をデプロイ対象としています。Function / Storage / Application Insights など本体リソースは後続フェーズ (Phase 1 以降) で `deploy.subscription.bicep` + `main.bicep` を有効化して展開します。

## ファイル一覧

- `main.bicep` : (Phase1以降で使用) Storage / Application Insights / Consumption Plan / Function App をまとめるテンプレート
- `deploy.subscription.bicep` : (Phase1以降) RG 作成 + main モジュール (現段階は未使用)
- `rg-only.bicep` : Phase0 で使用中 (Resource Group 単体)
- `parameters.poc.json` : PoC 用パラメータ (baseName / owner / expiresOn / signingSecret placeholder 等)
- `parameters.example.json` : 参考例 (将来複数環境化の雛形)

## 現段階 (Phase0) で作成されるリソース

1. Resource Group のみ

## 後続フェーズ (予告)
Phase1: 基本インフラ (Storage / App Insights / Plan / Function App)
Phase2: Key Vault 導入 & secret 参照化
Phase3: セキュリティ強化 (Private Endpoint / ネットワーク等 要件次第)

## 命名 & タグ

命名規則: `poc-<baseName>-<resource>` 例: `poc-ticket-guard-func`
Storage: `pocticketguard<uniqueSuffix>` (24 文字制約対応)

共通タグ (全リソース適用):
```
environment = poc
purpose     = poc
owner       = <メールアドレス>
expiresOn   = <YYYY-MM-DD>
app         = ticket-guard
```

## パラメータ方針

PoC ではサブスクリプション固有値をパラメータ化せず、環境は固定 `poc`。`signingSecret` は安全な保管先(Key Vault) 導入前の暫定。Key Vault 導入後は削除予定。

主要パラメータ (wrapper 経由):
- `baseName` : ベース名称 (例: `ticket-guard`)
- `owner` : 管理者 (タグ用)
- `expiresOn` : 有効期限 (自動クリーンアップ判断補助)
- `signingSecret` : HMAC 用シークレット (secureString)

## GitHub Actions ワークフロー構成 (Phase0)

| 用途 | ファイル | トリガ | 内容 |
|------|----------|--------|------|
| インフラ Plan (RG only) | `.github/workflows/infra-plan.yml` | PR / push (infra変更) | `rg-only.bicep` を what-if |
| インフラ Apply (RG only) | `.github/workflows/infra-apply.yml` | 手動 | RG 作成のみ |
| Functions テスト | `.github/workflows/functions-ci.yml` | PR / push (functions) | pytest 実行 |
| Functions デプロイ | `.github/workflows/functions-deploy.yml` | push(main) / 手動 | zip deploy (Function App 既存チェック) |

旧ワークフロー (`ci.yml`, `deploy.yml`, `functions-ci-deploy.yml`, `functions-unit-tests.yml`, `infra-deploy.yml`) は整理のため削除済みです。

## 実行フロー (推奨)

1. インフラ変更 PR 作成 → `infra-plan.yml` が what-if 結果を表示
2. レビュー/マージ後、必要に応じ `infra-apply.yml` を手動実行 (`confirm=APPLY`)
3. Function コード変更は `functions-ci.yml` でテスト → main 反映で `functions-deploy.yml` が zip デプロイ
4. 将来: Key Vault 追加 → `signingSecret` を Vault 参照に移行

## 手動デプロイ (ローカル開発補助)

PoC フローは基本 GitHub Actions 経由ですが、ローカルで挙動を確認したい場合:
```bash
az login
az deployment sub what-if \
  --name local-plan-001 \
  --location japaneast \
  --template-file infra/deploy.subscription.bicep \
  --parameters @infra/parameters.poc.json signingSecret="$(openssl rand -hex 16)"

az deployment sub create \
  --name local-apply-001 \
  --location japaneast \
  --template-file infra/deploy.subscription.bicep \
  --parameters @infra/parameters.poc.json signingSecret="$(openssl rand -hex 16)"
```

## Outputs
Phase0 (rg-only): なし (Resource Group 名は入力で確定するため明示出力不要)

Phase1 で wrapper 経由の各種出力 (Function 名 / PrincipalId など) を追加予定。

## 今後の Key Vault 移行 TODO (概要 / Phase2)

1. `main.bicep` に Key Vault モジュール(コメント) 追加
2. Vault 作成 (RBAC モード推奨) & タグ適用
3. Managed Identity に読み取りロール (Secrets User) 付与
4. `SIGNING_SECRET` を `az keyvault secret set` で投入
5. Function App `appSettings` を `@Microsoft.KeyVault(SecretUri=...)` 参照へ変更
6. `signingSecret` パラメータ削除 / README 更新

## 注意点

- 現状は RG のみなのでコスト極小・リソースサーフェス最小
- `signingSecret` パラメータは Phase1 以降で利用予定 (Phase0 では未消費)
- ネットワーク/セキュリティ強化は後続フェーズで検討

---
この README は PoC フェーズの最新構成に準拠しています。構成変更時はワークフロー表と Key Vault TODO を更新してください。