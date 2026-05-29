# ClangTail

ClangTail - это набор скриптов для добавления свежего LLVM/Clang в готовый Buildroot SDK. Проект собирает host-версию `clang` и `lld`, кросс-компилирует runtime-библиотеки LLVM под целевую систему, встраивает инструменты в архив с SDK и подготавливает отдельные пакеты с runtime-библиотеками для установки на целевое устройство

## Какую проблему решает

В Buildroot нельзя просто так взять и обновить GCC: версия компилятора обычно привязана к конкретной конфигурации toolchain, sysroot, libc и уже собранным пакетам. Из-за этого под систему может быть невозможно удобно компилировать код с новейшими стандартами C++ или с возможностями, которых нет в старом GCC

ClangTail предназначен для случаев, когда есть уже собранный Buildroot SDK, но поставляемый вместе с ним GCC слишком старый для нужного стандарта C++. Проект не пересобирает весь Buildroot и не заменяет системную сборочную инфраструктуру. Вместо этого он берёт существующий SDK как основу, собирает выбранную версию LLVM/Clang, добавляет в SDK кросс-компиляторы `${TRIPLE}-clang` и `${TRIPLE}-clang++`, а также собирает необходимые runtime-библиотеки под целевое устройство: `libc++`, `libc++abi`, `libunwind` и `compiler-rt`

Благодаря этому можно собрать свежий Clang поверх существующего Buildroot SDK и использовать его для компиляции приложений под ту же целевую платформу без изменений в самом Buildroot

## Что даёт на выходе

После успешной сборки в `build/` появляются основные артефакты:

- обновлённый архив с Buildroot SDK с добавленными LLVM-штуками:
    - `bin/clang`, `bin/clang++`, `bin/lld`, `bin/ld.lld` и набор базовых `llvm-*` утилит внутри SDK
    - симлинки `bin/${TRIPLE}-clang`, `bin/${TRIPLE}-clang++` и `bin/${TRIPLE}-ld.lld`
    - `clang-environment-setup` для настройки окружения для работы с Clang (аналогично лежащему рядом `environment-setup`)
    - `share/buildroot/clang-toolchainfile.cmake` для CMake-проектов (аналогично лежащему рядом `toolchainfile.cmake`)
    - runtime-библиотеки в `${TRIPLE}/sysroot/usr/lib`
- пакет `clangtail-runtimes_<LLVM_VERSION>_<ARCH>.deb` для установки runtime-библиотек на целевую систему
- самораспаковывающийся архив `clangtail-runtimes_<LLVM_VERSION>_<ARCH>.run` для тех же целей, если на платформе нет пакетного менеджера
- если при сборке был предоставлен образ системы - обновлённый образ с уже установленными runtime-библиотеками

## Что требует на вход

Проект требует готовый архив с Buildroot SDK (`make sdk` в Buildroot) и файл `config.json` (про него ниже). Архив нужно положить в `resources/` под тем именем, которое указано в конфиге

## Про процесс сборки

Основной сценарий сборки находится в `bootstrap.sh`. Он не принимает аргументов и читает настройки из `config.json`. Перед запуском скрипт очищает `build/`, но сохраняет `build/host-build`, чтобы избежать повторной сборки хостовых утилит LLVM, которая занимает довольно много времени. Если требуется полная пересборка проекта, `build/host-build` требуется удалить вручную

Процесс сборки разбит на стадии, скрипты которых находятся в `stages/`:

1. `stage_acquire_resources` проверяет наличие архива с SDK и скачивает исходники LLVM
2. `stage_prepare_resources` копирует архив с SDK (и образ системы, если есть) в `build/`, распаковывает исходники LLVM
3. `stage_build_host` собирает хостовые `clang`, `clang++` и `lld`
4. `stage_extract_sdk` распаковывает Buildroot SDK и находит sysroot по `${TRIPLE}/sysroot`
5. `stage_build_runtimes` собирает `libc++`, `libc++abi`, `libunwind` и `compiler-rt` под целевую платформу, используя SDK с собранными `clang/clang++/lld`
6. `stage_package_runtimes_deb` и `stage_package_runtimes_run` собирают пакеты с runtime-библиотеками
7. `stage_install_clang_sdk_toolchain` копирует собранные утилиты в SDK и генерирует файлы environment-setup и toolchain.cmake
8. `stage_patch_rootfs_image` при наличии образа перепаковывает его, добавляя runtime-библиотеки в `/usr/lib`
9. `stage_sanity_checks` проверяет наличие в SDK всего, что нужно
10. `stage_repack_sdk` упаковывает изменённый SDK обратно в архив

### Конфигурация

Конфиг в проекте один - `config.json`. Шаблон, на основе которого можно его создать - `example.config.json`

Поля конфига:

- `target_triple` - target triple системы, например `aarch64-vendor-linux-gnu`
- `llvm_version` - версия LLVM, инструменты которой будут собираться. Протестировано с версией `20.1.8`
- `sdk_archive_filename` - имя архива с Buildroot SDK в `resources/`.
- `rootfs_image_filename` - (опционально) имя образа системы в `resources/`, если его указать, туда добавятся собранные runtime-библиотеки

### Docker

`Dockerfile` основан на Ubuntu 24.04 и устанавливает все необходимые зависимости для сборки LLVM, упаковки runtime-библиотек и работы с образами через libguestfs

Перед запуском нужно подготовить локальный конфиг:

```bash
cp example.config.json config.json
# отредактировать config.json под свой SDK и версию LLVM
```

Собрать образ:

```bash
./docker/build.sh
```

Зайти в контейнер:

```bash
./docker/enter.sh
```

Запустить сборку:

```bash
cd clangtail
./bootstrap.sh
```

Количество потоков сборки можно задать переменной окружения (по умолчанию - `nproc`):

```bash
JOBS=16 ./bootstrap.sh
```

## Использование полученного SDK

После сборки можно распаковать обновлённый архив с SDK из `build/` куда-нибудь и сделать `./relocate-sdk.sh`

Пример сборки CMake-программы при помощи нового SDK:

```bash
source /path/to/toolchain/clang-environment-setup
cmake /path/to/project/root
make
```

## Запуск программ на целевом устройстве

Для этого на устройство необходимо установить runtime-библиотеки. Можно использовать `.deb`-пакет, если в системе есть совместимый пакетный менеджер. Если же такого нет, то можно просто запустить `.run`-пакет, он сам распакует необходимые библиотеки в соответствующие директории:

```bash
./clangtail-runtimes_<LLVM_VERSION>_<ARCH>.run
```
