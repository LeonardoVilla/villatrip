# Roteiro de Viagens

App Flutter offline-first para gerenciar roteiro de viagens. Os dados ficam no SQLite local e podem ser sincronizados com MongoDB via uma API Node/Express.

## Funcionalidades

- Cadastrar locais para visitar
- Informar localização/endereço
- Marcar locais como visitados
- Definir horários de funcionamento
- Definir tempo de deslocamento e horários de transporte
- Sincronizar alterações locais com MongoDB

## Como rodar o backend Mongo

1. Entre na pasta `backend`
2. Crie um arquivo `.env` com base em `.env.example`
3. Ajuste `MONGO_URI` para sua instância MongoDB
4. Execute:

```bash
npm install
npm start
```

Por padrão, a API sobe em `http://localhost:3000`.

## Como rodar o Flutter

```bash
flutter pub get
flutter run
```

Se estiver usando Android Emulator, o app usa automaticamente `http://10.0.2.2:3000` para falar com o backend local.

## Definir outra URL da API

Você pode sobrescrever a URL do backend com:

```bash
flutter run --dart-define=MONGO_API_URL=http://seu-servidor:3000
```

## Sincronização

Toque no ícone de sincronização na barra superior para:

- enviar itens locais pendentes para o Mongo
- baixar os itens do Mongo e atualizar o SQLite local

## Observação

No navegador, o app funciona para testes, mas a camada local usa memória em vez de SQLite persistente. Em mobile/desktop nativo, ele usa SQLite local de verdade.
