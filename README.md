# 📱 JALPlay - iPod Style MP3 Player for Android

<p align="center">
  <img src="img/logo.png" alt="JALPlay Logo" width="180" style="border-radius: 20%;" />
</p>

<p align="center">
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" /></a>
  <a href="https://dart.dev"><img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" /></a>
  <a href="https://developer.android.com"><img src="https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white" alt="Android" /></a>
  <img src="https://img.shields.io/badge/Status-Completo-brightgreen?style=for-the-badge" alt="Status" />
</p>

---

**JALPlay** é um reprodutor de música MP3 offline para Android que traz de volta a nostalgia dos anos 2000. Ele simula com precisão a interface física clássica de um **iPod**, incluindo a icônica **Click Wheel** interativa e uma tela LCD digital estilizada com luz de fundo dinâmica. 

O projeto foi construído usando **Flutter** e utiliza as melhores práticas de processamento de áudio em segundo plano com integração nativa no Android.

---

## 📸 Demonstração da Interface

<p align="center">
  <!-- Captura de tela do repositório -->
  <img src="https://github.com/deartis/jalplay/raw/master/img/logo2.png" alt="JALPlay Interface" width="280" style="border-radius: 12px; box-shadow: 0 4px 8px rgba(0,0,0,0.2);" />
</p>

---

## ✨ Principais Funcionalidades

- **🎛️ Click Wheel Interativa**:
  - **Deslizar Rotativo**: Deslize o dedo ao redor da roda para navegar por listas de reprodução ou ajustar o volume da música em tempo real.
  - **Feedback Tátil**: Vibrações dinâmicas micro-calculadas ao passar por itens da lista para simular a sensação da roda mecânica original.
  - **Menu e Botões de Mídia**: Botões físicos de MENU, ⏮ (Anterior), ⏭ (Próxima) e ▶II (Play/Pause) desenhados de forma vetorial e responsiva no canvas.
  - **Botão Central**: Toque rápido para selecionar/entrar em menus e toque longo para favoritar a música atual.
  
- **🎵 Reprodutor de Áudio Robusto**:
  - Leitura automática da biblioteca de música local do aparelho (com permissões seguras).
  - Suporte a reprodução em segundo plano com controle na barra de notificações nativa do Android (`audio_service`).
  - Suporte a Album Art (capas das músicas) dinâmico com efeito giratório na tela "Now Playing".
  
- **📟 Tela LCD Estilizada**:
  - Menu clássico em lista deslizante e transições dinâmicas.
  - Painel de reprodução detalhado contendo barra de progresso interativa, indicador de bateria dinâmico, modos de repetição e shuffle.
  - Mini-player na parte inferior da tela LCD durante a navegação em outros menus.
  - Barra de volume com overlay dinâmico.

---

## 🛠️ Tecnologias Utilizadas

- **[Flutter](https://flutter.dev)**: Framework UI multiplataforma da Google.
- **[just_audio](https://pub.dev/packages/just_audio)**: API de reprodução de áudio de alta performance.
- **[audio_service](https://pub.dev/packages/audio_service)**: Integração com controles de mídia em segundo plano do Android.
- **[on_audio_query](https://pub.dev/packages/on_audio_query)**: Consulta segura e eficiente de arquivos de mídia locais.
- **[provider](https://pub.dev/packages/provider)**: Gerenciamento de estado limpo e reativo.
- **[battery_plus](https://pub.dev/packages/battery_plus)**: Acesso ao estado da bateria do dispositivo para o indicador do LCD.

---

## 🎮 Guia de Gestos do Reprodutor

| Ação | Gesto na Click Wheel |
| :--- | :--- |
| **Navegar nas Listas** | Deslizar o dedo rotativamente na roda |
| **Ajustar Volume** | Deslizar o dedo rotativamente na roda (quando na tela *Now Playing*) |
| **Voltar Menu** | Pressionar o botão **MENU** (topo da roda) |
| **Selecionar Item** | Pressionar o **Botão Central** |
| **Favoritar Música** | Pressionar e segurar (**Long Press**) o **Botão Central** |
| **Play / Pause** | Pressionar o botão **▶II** (base da roda) |
| **Próxima Música** | Pressionar o botão **⏭** (direita da roda) |
| **Música Anterior** | Pressionar o botão **⏮** (esquerda da roda) |

---

## 🚀 Como Executar o Projeto Localmente

### Pré-requisitos:
- Flutter SDK instalado em sua máquina.
- Um dispositivo Android conectado ou um Emulador configurado.

### Passos para rodar:

1. **Clonar o repositório**:
   ```bash
   git clone https://github.com/deartis/jalplay.git
   cd jalplay
   ```

2. **Baixar as dependências do Flutter**:
   ```bash
   flutter pub get
   ```

3. **Rodar o aplicativo no dispositivo**:
   ```bash
   flutter run
   ```

---

## 📁 Estrutura de Pastas Principal

```text
lib/
├── models/            # Modelo de dados da música
├── providers/         # Gerenciamento de estado global (PlayerProvider)
├── screens/           # Telas do app (IpodScreen, SearchScreen)
├── services/          # Serviços nativos (JalPlayAudioHandler)
├── widgets/           # Componentes UI reutilizáveis (ClickWheel, LcdDisplay, NowPlayingScreen, etc.)
└── main.dart          # Inicialização das configurações do app
```

## 🚫 Sem Anúncios (No Ads)

> [!IMPORTANT]
> **Por favor, não adicione propagandas ou anúncios neste projeto.**
> O JALPlay nasceu justamente do desejo de ter um reprodutor de música limpo, focado na experiência do usuário e livre de anúncios irritantes ou interrupções comerciais. Se você for criar um fork ou distribuir uma versão deste aplicativo, **mantenha-o 100% gratuito e livre de anúncios**.

---

## ☕ Apoie o Projeto (Pague um Café)

Se este projeto foi útil para você ou se você apoia a ideia de mantermos o reprodutor de mídia totalmente gratuito e sem anúncios, sinta-se à vontade para me pagar um café!

**Chave Pix (Aleatória):**
```text
7b16efd5-bf9d-438c-b48c-e30419704613
```

Qualquer apoio é super bem-vindo! ☕✨

---

## 📄 Licença

Este projeto está sob licença livre. Sinta-se à vontade para clonar, estudar e customizar o código!

Feito com ❤️ por **[Deartis](https://github.com/deartis)**.
