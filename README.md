# Scripts de limpeza e diagnóstico para macOS

Coleção de scripts Bash para encontrar arquivos grandes e limpar caches comuns do macOS, com foco em desenvolvimento, navegadores, Docker, Xcode/iOS e Android.

> Recomendação: rode primeiro com `--dry-run` sempre que o script oferecer essa opção. Assim você vê o que seria removido antes de apagar qualquer coisa.

## Requisitos

- macOS.
- Bash disponível no terminal.
- Permissão para acessar as pastas do seu usuário.
- Ferramentas opcionais conforme o script: `docker`, `brew`, `npm`, `yarn`, `pnpm`, `go`, `watchman`, `xcrun`, `adb`, `pod`.

Os scripts não precisam de `sudo` para o uso normal. Evite rodar com `sudo`, porque eles foram pensados para limpar arquivos do usuário atual.

## Como usar

Entre na pasta do projeto:

```bash
cd /clean-script
```

Execute um script com `bash`:

```bash
bash mac-space-report.sh
bash clean-system-safe.sh --dry-run
```

Ou execute diretamente, se o arquivo estiver com permissão de execução:

```bash
./mac-space-report.sh
./clean-system-safe.sh --dry-run
```

Para ver a ajuda de qualquer script:

```bash
bash nome-do-script.sh --help
```

## Opções comuns

Alguns scripts compartilham estas opções:

| Opção          | O que faz                                                             |
| -------------- | --------------------------------------------------------------------- |
| `--dry-run`    | Mostra o que seria removido, sem apagar nada.                         |
| `--yes`        | Confirma automaticamente as ações que normalmente perguntariam antes. |
| `-h`, `--help` | Mostra a ajuda do script.                                             |

## Comandos disponíveis

### `mac-space-report.sh`

Mostra um relatório de uso de espaço. Não apaga nada.

```bash
bash mac-space-report.sh
```

Opções:

| Opção           | O que faz                                              |
| --------------- | ------------------------------------------------------ |
| `--limit N`     | Define quantos itens aparecem por seção. Padrão: `25`. |
| `--roots PATHS` | Define as pastas analisadas, separadas por vírgula.    |

Exemplos:

```bash
bash mac-space-report.sh --limit 30
bash mac-space-report.sh --roots "$HOME/Downloads,$HOME/Documents"
```

### `clean-system-safe.sh`

Limpa temporários, logs, crash reports e caches antigos do usuário de forma conservadora.

```bash
bash clean-system-safe.sh --dry-run
```

Opções:

| Opção           | O que faz                                                                      |
| --------------- | ------------------------------------------------------------------------------ |
| `--days N`      | Remove apenas itens antigos com mais de `N` dias onde aplicável. Padrão: `30`. |
| `--empty-trash` | Esvazia `~/.Trash` após confirmação.                                           |

Exemplos:

```bash
bash clean-system-safe.sh --dry-run --days 30
bash clean-system-safe.sh --yes --days 60
bash clean-system-safe.sh --yes --empty-trash
```

### `clean-browser-caches.sh`

Limpa caches de Chrome, Microsoft Edge, Firefox e Safari sem apagar perfis, cookies, histórico ou extensões.

```bash
bash clean-browser-caches.sh --dry-run
```

Opções:

| Opção          | O que faz                                              |
| -------------- | ------------------------------------------------------ |
| `--close-apps` | Tenta fechar os navegadores antes de limpar os caches. |

Exemplos:

```bash
bash clean-browser-caches.sh --dry-run
bash clean-browser-caches.sh --yes --close-apps
```

### `clean-dev-caches.sh`

Limpa caches gerais de desenvolvimento, incluindo Homebrew, Node.js, Python, Ruby, Go, Rust, VS Code e JetBrains.

```bash
bash clean-dev-caches.sh --dry-run
```

Opções:

| Opção           | O que faz                                          |
| --------------- | -------------------------------------------------- |
| `--deep`        | Inclui caches maiores e stores de pacotes.         |
| `--with-docker` | Também executa uma limpeza conservadora do Docker. |

Exemplos:

```bash
bash clean-dev-caches.sh --dry-run
bash clean-dev-caches.sh --yes --deep
bash clean-dev-caches.sh --yes --with-docker
```

### `clean-mobile-caches.sh`

Limpa caches de builds iOS/Android/Metro e caches relacionados a desenvolvimento mobile.

```bash
bash clean-mobile-caches.sh --dry-run
```

Opções:

| Opção                     | O que faz                                                                        |
| ------------------------- | -------------------------------------------------------------------------------- |
| `--deep`                  | Inclui caches pesados como npm, Yarn, pnpm, CocoaPods, SwiftPM e Gradle wrapper. |
| `--erase-ios-sims`        | Apaga os dados de todos os simuladores iOS.                                      |
| `--delete-avds`           | Apaga todos os AVDs em `~/.android/avd`.                                         |
| `--delete-xcode-archives` | Apaga archives exportados do Xcode. Não é cache.                                 |
| `--delete-device-support` | Apaga suportes de devices iOS baixados pelo Xcode.                               |
| `--projects PATHS`        | Limpa a pasta `android/` de outros projetos, separados por vírgula.              |
| `--empty-trash`           | Esvazia a lixeira do macOS.                                                      |

Exemplos:

```bash
bash clean-mobile-caches.sh --dry-run
bash clean-mobile-caches.sh --dry-run --deep
bash clean-mobile-caches.sh --yes --deep --erase-ios-sims
bash clean-mobile-caches.sh --yes --projects "$HOME/projetos/app1,$HOME/projetos/app2"
```

Use as opções `--erase-ios-sims`, `--delete-avds`, `--delete-xcode-archives` e `--delete-device-support` com cuidado, porque elas removem dados que podem precisar ser baixados ou recriados depois.

### `clean-ios-backups.sh`

Lista e remove backups locais de iPhone/iPad em `~/Library/Application Support/MobileSync/Backup`.

```bash
bash clean-ios-backups.sh
```

Opções:

| Opção                   | O que faz                           |
| ----------------------- | ----------------------------------- |
| `--delete-older-than N` | Apaga backups com mais de `N` dias. |
| `--delete-all`          | Apaga todos os backups locais.      |

Exemplos:

```bash
bash clean-ios-backups.sh
bash clean-ios-backups.sh --dry-run --delete-older-than 90
bash clean-ios-backups.sh --yes --delete-older-than 180
```

### `clean-docker.sh`

Limpa recursos Docker não usados. Por padrão remove containers, networks, builder cache e imagens dangling.

```bash
bash clean-docker.sh --dry-run
```

Opções:

| Opção          | O que faz                                                            |
| -------------- | -------------------------------------------------------------------- |
| `--aggressive` | Remove todas as imagens não usadas, não apenas dangling.             |
| `--volumes`    | Inclui volumes Docker não usados. Pode apagar bancos e dados locais. |

Exemplos:

```bash
bash clean-docker.sh --dry-run
bash clean-docker.sh --yes
bash clean-docker.sh --yes --aggressive
bash clean-docker.sh --yes --aggressive --volumes
```

Use `--volumes` somente quando tiver certeza de que os volumes não contêm dados importantes.

### `mac-clean-lib.sh`

Biblioteca interna usada pelos outros scripts. Ela centraliza funções de confirmação, remoção segura, cálculo de espaço potencial liberado, `--dry-run` e relatório final.

Normalmente você não executa este arquivo diretamente.

## Fluxo recomendado de limpeza

1. Veja onde está o maior uso de espaço:

   ```bash
   bash mac-space-report.sh --limit 30
   ```

2. Simule a limpeza desejada:

   ```bash
   bash clean-system-safe.sh --dry-run
   bash clean-dev-caches.sh --dry-run
   bash clean-browser-caches.sh --dry-run
   ```

3. Se o resultado fizer sentido, rode de verdade:

   ```bash
   bash clean-system-safe.sh --yes
   bash clean-dev-caches.sh --yes
   bash clean-browser-caches.sh --yes
   ```

4. Para limpeza mobile ou Docker, simule primeiro e revise com mais cuidado:

   ```bash
   bash clean-mobile-caches.sh --dry-run --deep
   bash clean-docker.sh --dry-run --aggressive
   ```
