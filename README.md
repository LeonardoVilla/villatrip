# Roteiro de Viagens

App Flutter offline-first para gerenciar roteiro de viagens. Os dados ficam no SQLite local (nativo) ou em memória (web) e são sincronizados com o Firestore do Firebase.

## Funcionalidades

- Cadastrar locais para visitar com horários e transporte
- Marcar locais como visitados
- Criar rolês do dia com locais, horários e gastos
- Relatórios de gastos com filtro de período
- Sincronização automática com Firestore (por usuário autenticado)

## Firebase / Firestore

### Estrutura de coleções

```
users/{uid}/places/{id}           ← locais do usuário
users/{uid}/day_plans/{id}        ← rolês do dia
users/{uid}/day_plans/{id}/items/{id}  ← locais de cada rolê
```

### Regras de segurança (Firestore)

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### O que é sincronizado

| Entidade       | Push (local → Firestore) | Pull (Firestore → local) |
|----------------|--------------------------|--------------------------|
| Locais         | ✅ quando `needsSync=true` | ✅ todos ao sincronizar   |
| Rolês do dia   | ✅ quando `needsSync=true` | ✅ todos ao sincronizar   |
| Itens do rolê  | ✅ quando `needsSync=true` | ✅ todos ao sincronizar   |

A sincronização ocorre automaticamente ao abrir cada tela e pode ser acionada manualmente com o botão de nuvem na AppBar.

## Schema SQLite (versão 5)

```sql
places: id, remote_id, name, location, opening_time, closing_time,
        commute_duration, transport_schedule, updated_at, needs_sync, visited

day_plans: id, remote_id, date, title, notes, created_at, needs_sync

day_plan_items: id, remote_id, day_plan_id, place_id, place_remote_id,
                arrival_time, leave_time, amount_spent, notes, sort_order, needs_sync
```

## Como rodar o Flutter

```bash
flutter pub get
flutter run
```

## Deploy no Vercel (Flutter Web)

Este repositório possui o arquivo `vercel.json` configurado para buildar o Flutter Web.

1. No Vercel, importe o repositório.
2. Em **Build and Output Settings**, mantenha `build/web` como output.
3. Faça o deploy.

## Dependências principais

| Pacote | Versão | Motivo |
|--------|--------|--------|
| `firebase_core` | ^4.9.0 | Inicialização do Firebase |
| `firebase_auth` | ^6.0.0 | Autenticação de usuários |
| `cloud_firestore` | ^6.0.0 | Banco de dados em nuvem |
| `sqflite` | ^2.4.2 | SQLite local (nativo) |
| `path` | ^1.9.0 | Caminhos de arquivo |
| `path_provider` | ^2.1.4 | Pasta de banco de dados |
| `intl` | ^0.20.2 | Formatação de datas e moeda |

## Observação

No navegador, o app usa armazenamento em memória em vez de SQLite. Os dados persistem via Firestore se o usuário estiver autenticado.

