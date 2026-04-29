[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# Сервер Headscale на Docker

[![Build Status](https://github.com/hwdsl2/docker-headscale/actions/workflows/main.yml/badge.svg)](https://github.com/hwdsl2/docker-headscale/actions/workflows/main.yml) &nbsp;[![License: MIT](docs/images/license.svg)](https://opensource.org/licenses/MIT)

Docker-образ для запуска сервера [Headscale](https://github.com/juanfont/headscale) — самостоятельно размещаемой реализации координационного сервера Tailscale с открытым исходным кодом. Подключите все свои устройства с помощью официальных клиентских приложений Tailscale, управляя ими через собственный сервер.

**Возможности:**

- Автоматическая генерация конфигурации сервера и ключа предварительной авторизации при первом запуске
- Управление пользователями, узлами и ключами через вспомогательный скрипт (`hs_manage`)
- Поддержка MagicDNS для бесшовного разрешения имён хостов в сети
- Автоматически собирается и публикуется через [GitHub Actions](https://github.com/hwdsl2/docker-headscale/actions/workflows/main.yml)
- Постоянное хранение данных через Docker volume
- Поддержка нескольких архитектур: `linux/amd64`, `linux/arm64`

**Также доступно:**

- Без Docker: [Скрипт установки Headscale](https://github.com/hwdsl2/headscale-install/blob/main/README-ru.md)
- VPN: [WireGuard](https://github.com/hwdsl2/docker-wireguard/blob/main/README-ru.md), [OpenVPN](https://github.com/hwdsl2/docker-openvpn/blob/main/README-ru.md), [IPsec VPN](https://github.com/hwdsl2/docker-ipsec-vpn-server/blob/master/README-ru.md)
- ИИ/Аудио: [Whisper (STT)](https://github.com/hwdsl2/docker-whisper/blob/main/README-ru.md), [Kokoro (TTS)](https://github.com/hwdsl2/docker-kokoro/blob/main/README-ru.md), [Embeddings](https://github.com/hwdsl2/docker-embeddings/blob/main/README-ru.md), [LiteLLM](https://github.com/hwdsl2/docker-litellm/blob/main/README-ru.md), [Ollama](https://github.com/hwdsl2/docker-ollama/blob/main/README-ru.md)

## Быстрый старт

### Необходимые условия

Настоятельно рекомендуется использовать публично доступный сервер с доменным именем и TLS-сертификатом. Варианты настройки см. в разделе [TLS и обратный прокси](#tls-и-обратный-прокси).

### Использование Docker

Создайте файл `vpn.env`. `HS_SERVER_URL` — это HTTPS-адрес, по которому клиенты Tailscale подключаются к вашему серверу. Все доступные параметры см. в разделе [Переменные окружения](#переменные-окружения).

```
HS_SERVER_URL=https://hs.example.com
```

Запустите контейнер:

```bash
docker run \
  --name headscale \
  --restart=always \
  -p 127.0.0.1:8080:8080/tcp \
  -v headscale-data:/var/lib/headscale \
  -v ./vpn.env:/vpn.env:ro \
  -d hwdsl2/headscale-server
```

**Примечание:** При использовании приведённой команды порт `8080` привязан только к локальному хосту. Для подключения клиентов Tailscale необходим обратный прокси на хосте, который обрабатывает TLS и перенаправляет трафик на `127.0.0.1:8080`. См. раздел [TLS и обратный прокси](#tls-и-обратный-прокси). Чтобы вместо этого открыть порт напрямую, замените `127.0.0.1:8080:8080` на `8080:8080`.

В качестве альтернативы вы можете [настроить Headscale без Docker](https://github.com/hwdsl2/headscale-install/blob/main/README-ru.md). Чтобы узнать больше о том, как использовать этот образ, прочитайте разделы ниже.

При первом запуске контейнер:
1. Сгенерирует конфигурацию сервера из переменных окружения
2. Создаст начального пользователя (по умолчанию: `admin`)
3. Выведет **многоразовый ключ предварительной авторизации** в логи контейнера

Получите начальный ключ предварительной авторизации из логов:

```bash
docker logs headscale
```

<details>
<summary>
Нажмите, чтобы увидеть пример вывода.
</summary>

![screenshot](docs/images/screenshot.png)
</details>

Подключите устройство с помощью официального [клиента Tailscale](https://tailscale.com/download):

```bash
tailscale up --login-server https://hs.example.com --authkey <ключ-из-логов>
```

### Использование Docker Compose

```bash
cp vpn.env.example vpn.env
nano vpn.env        # Укажите как минимум HS_SERVER_URL
docker compose up -d
docker compose logs headscale
```

Пример `docker-compose.yml` (уже включён):

```yaml
services:
  headscale:
    image: hwdsl2/headscale-server
    container_name: headscale
    restart: always
    ports:
      - "127.0.0.1:8080:8080/tcp"
    volumes:
      - headscale-data:/var/lib/headscale
      - ./vpn.env:/vpn.env:ro

volumes:
  headscale-data:
```

## Загрузка

Получите образ из [реестра Docker Hub](https://hub.docker.com/r/hwdsl2/headscale-server/):

```bash
docker pull hwdsl2/headscale-server
```

Либо загрузите из [Quay.io](https://quay.io/repository/hwdsl2/headscale-server):

```bash
docker pull quay.io/hwdsl2/headscale-server
docker image tag quay.io/hwdsl2/headscale-server hwdsl2/headscale-server
```

Поддерживаемые платформы: `linux/amd64` и `linux/arm64`.

## Настройка клиентов

Инструкции по подключению клиентов см. в документации Headscale:

- [Android](https://headscale.net/stable/usage/connect/android/)
- [Apple (iOS / macOS)](https://headscale.net/stable/usage/connect/apple/)
- [Windows](https://headscale.net/stable/usage/connect/windows/)

## Переменные окружения

Все переменные необязательны. `HS_SERVER_URL` настоятельно рекомендуется задать для production-использования.

| Переменная | Значение по умолчанию | Описание |
|---|---|---|
| `HS_SERVER_URL` | Автоопределение | URL для подключения клиентов Tailscale (например, `https://hs.example.com`). Для полной функциональности клиентов необходим HTTPS. |
| `HS_LISTEN_PORT` | `8080` | TCP-порт, на котором слушает сервер. |
| `HS_METRICS_PORT` | `9090` | Порт метрик Prometheus. Оставьте пустым для отключения. |
| `HS_BASE_DOMAIN` | `headscale.internal` | Базовый домен для имён хостов MagicDNS (например, `myhost.headscale.internal`). Не должен совпадать с именем хоста в `HS_SERVER_URL` или быть его родительским доменом (например, если `HS_SERVER_URL=https://hs.example.com`, не используйте `example.com`). |
| `HS_USERNAME` | `admin` | Имя первого пользователя, создаваемого при начальной настройке. |
| `HS_DNS_SRV1` | `1.1.1.1` | Основной DNS-сервер, передаваемый клиентам через MagicDNS. Принимает IPv4 или IPv6. |
| `HS_DNS_SRV2` | `1.0.0.1` | Резервный DNS-сервер, передаваемый клиентам через MagicDNS. |
| `HS_LOG_LEVEL` | `info` | Уровень подробности логов: `panic`, `fatal`, `error`, `warn`, `info`, `debug`, `trace`. |

**Примечание:** В файле `env` можно заключать значения в одинарные кавычки, например `VAR='значение'`. Не добавляйте пробелы вокруг `=`.

Файл конфигурации пересоздаётся при каждом запуске контейнера. Для изменения настройки обновите `vpn.env` и перезапустите контейнер. Файл env монтируется в контейнер через bind mount, поэтому изменения применяются при каждом перезапуске без пересоздания контейнера.

## TLS и обратный прокси

Клиенты Tailscale лучше всего работают с HTTPS. Рекомендуемая схема — запустить перед Headscale обратный прокси, обрабатывающий завершение TLS, затем задать `HS_SERVER_URL` равным вашему HTTPS-URL.

Используйте один из следующих адресов для обращения к контейнеру Headscale из обратного прокси:

- **`headscale:8080`** — если обратный прокси запущен как контейнер в **той же Docker-сети**, что и Headscale (например, определён в одном `docker-compose.yml`). Docker автоматически разрешает имя контейнера.
- **`127.0.0.1:8080`** — если обратный прокси запущен **на хосте** и порт `8080` опубликован (файл `docker-compose.yml` по умолчанию публикует его).

**Примечание:** Не используйте внутренний IP-адрес контейнера, полученный через `docker inspect`. Этот адрес меняется при каждом пересоздании контейнера.

**Пример с [Caddy](https://caddyserver.com/docs/) ([Docker-образ](https://hub.docker.com/_/caddy))** (автоматический TLS через Let's Encrypt, обратный прокси в той же Docker-сети):

`Caddyfile`:
```
hs.example.com {
  reverse_proxy headscale:8080
}
```

**Пример с nginx** (обратный прокси на хосте):

```nginx
server {
  listen 443 ssl;
  server_name hs.example.com;

  ssl_certificate     /path/to/cert.pem;
  ssl_certificate_key /path/to/key.pem;

  location / {
    proxy_pass http://127.0.0.1:8080;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_read_timeout 3600s;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
  }
}
```

Задайте `HS_SERVER_URL=https://hs.example.com` в файле `vpn.env` и перезапустите контейнер.

**Порты для открытия в файрволе:**

| Порт | Протокол | Назначение |
|---|---|---|
| `8080` | TCP | Координационный сервер Headscale (или порт обратного прокси) |
| `443` | TCP | HTTPS (при использовании обратного прокси) |
| `9090` | TCP | Метрики Prometheus (необязательно, по умолчанию не публикуется) |

## Управление сервером

Используйте вспомогательный скрипт `hs_manage` для управления пользователями и узлами с хоста без входа в контейнер.

**Зарегистрировать узел по его ключу:**

```bash
docker exec headscale hs_manage --registernode <key> --user admin
```

**Добавить пользователя:**

```bash
docker exec headscale hs_manage --adduser alice
```

**Удалить пользователя:**

```bash
docker exec -it headscale hs_manage --deleteuser alice
# Или без запроса подтверждения:
docker exec headscale hs_manage --deleteuser alice --yes
```

**Создать ключ предварительной авторизации для пользователя:**

```bash
docker exec headscale hs_manage --createkey --user alice
```

**Список пользователей:**

```bash
docker exec headscale hs_manage --listusers
```

**Список всех зарегистрированных узлов:**

```bash
docker exec headscale hs_manage --listnodes
```

**Список узлов конкретного пользователя:**

```bash
docker exec headscale hs_manage --listnodes --user alice
```

**Удалить узел по ID:**

```bash
docker exec -it headscale hs_manage --deletenode 3
# Или без запроса подтверждения:
docker exec headscale hs_manage --deletenode 3 --yes
```

**Список всех ключей предварительной авторизации:**

```bash
docker exec headscale hs_manage --listkeys
```

**Показать справку:**

```bash
docker exec headscale hs_manage --help
```

Также можно выполнять команды Headscale напрямую с помощью `docker exec headscale headscale <команда>`. Выполните `docker exec headscale headscale -h` или см. [документацию Headscale](https://headscale.net/) для просмотра доступных команд.

## Обновление Docker-образа

Для обновления Docker-образа и контейнера сначала [загрузите](#загрузка) последнюю версию:

```bash
docker pull hwdsl2/headscale-server
```

Если Docker-образ уже актуален, вы увидите:

```
Status: Image is up to date for hwdsl2/headscale-server:latest
```

В противном случае будет загружена последняя версия. Удалите и пересоздайте контейнер, следуя инструкциям из раздела [Быстрый старт](#быстрый-старт). Ваши данные сохранены в volume `headscale-data`.

## Технические детали

- Базовый образ: `alpine:3.23`
- Headscale: 0.28.0
- Каталог данных: `/var/lib/headscale` (Docker volume)
- Конфигурация: генерируется из `vpn.env` при каждом запуске контейнера; чтобы применить изменения, обновите `vpn.env` и перезапустите контейнер (пересоздание контейнера не требуется)
- Порты: `8080/tcp` (координационный сервер), `9090/tcp` (метрики Prometheus, необязательно)
- Платформы: `linux/amd64`, `linux/arm64`

## Лицензия

**Примечание:** Программные компоненты внутри предсобранного образа (такие как Headscale) распространяются под соответствующими лицензиями, выбранными их правообладателями. При использовании любого предсобранного образа пользователь несёт ответственность за соблюдение всех соответствующих лицензий на программное обеспечение, содержащееся в образе.

Copyright (C) 2026 Lin Song   
Эта работа распространяется под [лицензией MIT](https://opensource.org/licenses/MIT).

**Headscale** является Copyright (c) 2020, Juan Font, и распространяется под [лицензией BSD 3-Clause](https://github.com/juanfont/headscale/blob/main/LICENSE).

Tailscale® является зарегистрированным товарным знаком Tailscale Inc. Данный проект не связан с Tailscale Inc. и не одобрен ею.