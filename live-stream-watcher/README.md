# 📺 live-stream-watcher (Vercel deployment guide)

Este serviço monitora duas fontes em tempo real:
1. **Transmissão HLS (M3U8)**: checada a cada 1 minuto para detectar quando a TV Itapê entra no ar e disparar a notificação de live.
2. **Notícias do WordPress**: checada a cada 1-5 minutos para disparar notificações automáticas quando novas matérias forem publicadas no site `xeh.com.br`.

---

## 🛠️ Passo 1: Gerar a Chave Privada do Firebase (JSON)

Para permitir que o Vercel se conecte de forma segura ao seu Firebase e dispare as notificações, você precisa da chave de conta de serviço:

1. Acesse o [Firebase Console](https://console.firebase.google.com/) e entre no projeto **`tvi-news`**.
2. Clique no ícone de engrenagem ⚙️ (ao lado de "Visão geral do projeto") e selecione **Configurações do projeto**.
3. Vá na aba **Contas de serviço**.
4. Clique no botão azul **"Gerar nova chave privada"** no final da página.
5. Um arquivo `.json` será baixado no seu computador. Abra ele com o Bloco de Notas ou VS Code e **copie todo o seu conteúdo** (você usará isso no Passo 3).

---

## 🚀 Passo 2: Publicar no Vercel

O Vercel hospedará a API gratuitamente.

1. Abra o terminal do seu computador no VS Code.
2. Navegue até a pasta do serviço:
   ```bash
   cd live-stream-watcher
   ```
3. Rode o comando de publicação do Vercel:
   ```bash
   npx vercel
   ```
4. **Siga as instruções na tela:**
   - *Log in to Vercel?* Escolha como prefere fazer login (ex: GitHub, Email ou Google - é grátis).
   - *Set up and deploy?* Escolha `Y` (Sim).
   - *Which scope?* Aperte Enter no seu nome/time.
   - *Link to existing project?* Escolha `N` (Não, pois é um projeto novo).
   - *What's your project's name?* Deixe `live-stream-watcher` e aperte Enter.
   - *In which directory is your code located?* Deixe `./` e aperte Enter.
   - *Want to modify these settings?* Escolha `N` (Não).
5. O Vercel fará o primeiro deploy ("Preview").

---

## 🔒 Passo 3: Adicionar a Chave no Painel do Vercel

Agora, salve a chave privada do Firebase no Vercel para que ele consiga rodar:

1. No terminal do VS Code, após o deploy acima terminar, copie o link que aparece em **`Project Console`** (ex: `https://vercel.com/seu-usuario/live-stream-watcher`) e abra-o no seu navegador.
2. No painel do seu projeto no site do Vercel, clique na aba **Settings** (Configurações) no topo.
3. No menu esquerdo, selecione **Environment Variables** (Variáveis de Ambiente).
4. Adicione a variável:
   - **Key (Chave):** `FIREBASE_SERVICE_ACCOUNT`
   - **Value (Valor):** Cole todo o texto do arquivo JSON que você copiou no Passo 1.
5. Clique em **Save** (Salvar).

---

## ⚡ Passo 4: Fazer o Deploy Final (Produção)

No terminal do VS Code, rode o comando abaixo para aplicar a chave de segurança no servidor de produção:

```bash
npx vercel --prod
```

Ao terminar, o Vercel te dará a **URL de Produção** oficial do seu projeto (ex: `https://live-stream-watcher-xxxx.vercel.app`).
Suas duas APIs estarão ativas nos endereços:
* **Validador de Live (HLS):** `https://live-stream-watcher-xxxx.vercel.app/api/watch-stream`
* **Monitor de Notícias (WordPress):** `https://live-stream-watcher-xxxx.vercel.app/api/watch-news`

---

## 🕐 Passo 5: Configurar os Cron Jobs no cron-job.org

Para fazer o Vercel rodar a checagem de graça na nuvem 24/7:

1. Acesse o site [cron-job.org](https://cron-job.org/) e crie/entre na sua conta gratuita.
2. Clique no menu lateral **Cron Jobs** e depois em **Create Cron Job** (Criar Cron Job).

### Cron 1: Checagem da Live (A cada 1 minuto)
* **Title:** `TV Itapê Stream Watcher`
* **URL:** Cole a sua URL de produção da API do Vercel finalizada com `/api/watch-stream` (Exemplo: `https://live-stream-watcher-xxxx.vercel.app/api/watch-stream`).
* **Schedule (Frequência):** Selecione **Every 1 minute** (A cada 1 minuto).
* Clique em **Create** (Criar).

### Cron 2: Checagem de Novas Notícias (A cada 1 a 5 minutos)
* **Title:** `TV Itapê WordPress News Watcher`
* **URL:** Cole a sua URL de produção da API do Vercel finalizada com `/api/watch-news` (Exemplo: `https://live-stream-watcher-xxxx.vercel.app/api/watch-news`).
* **Schedule (Frequência):** Selecione **Every 2 minutes** ou **Every 5 minutes** (recomenda-se a cada 2 ou 5 minutos).
* Clique em **Create** (Criar).

Pronto! Os dois cron jobs rodarão de forma automática na nuvem sem precisar manter seu computador ligado. 🍊📺

