#!/bin/bash
DISTRIBUTION=("ubuntu22.04")

if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID

    if [[ ! " ${DISTRIBUTION[@]} " =~ " ${OS}${VERSION} " ]]; then
        echo -e "\e[0;31mThis distribution is currently not supported\e[0m"
        exit $?
    fi
else
    echo -e "\e[0;31mUnable to determine the distribution\e[0m"
    exit $?
fi

COLOR_BLACK="\e[0;30m"
COLOR_RED="\e[0;31m"
COLOR_GREEN="\e[0;32m"
COLOR_ORANGE="\e[0;33m"
COLOR_BLUE="\e[0;34m"
COLOR_PURPLE="\e[0;35m"
COLOR_CYAN="\e[0;36m"
COLOR_LIGHT_GRAY="\e[0;37m"
COLOR_DARK_GRAY="\e[1;30m"
COLOR_LIGHT_RED="\e[1;31m"
COLOR_LIGHT_GREEN="\e[1;32m"
COLOR_YELLOW="\e[1;33m"
COLOR_LIGHT_BLUE="\e[1;34m"
COLOR_LIGHT_PURPLE="\e[1;35m"
COLOR_LIGHT_CYAN="\e[1;36m"
COLOR_WHITE="\e[1;37m"
COLOR_END="\e[0m"

ROOT=$(pwd)

ERROR_INSTALL_PACKAGES="An error occurred while trying to install the required packages"
ERROR_DOWNLOAD_SOURCE="An error occurred while trying to download the source code"
ERROR_DOWNLOAD_SOURCE_MODULE="An error occurred while trying to download the source code of"
ERROR_UPDATE_SOURCE="An error occurred while trying to update the source code"
ERROR_UPDATE_SOURCE_MODULE="An error occurred while trying to update the source code of"
ERROR_COMPILE_SOURCE="An error occurred while trying to compile the source code"
ERROR_DOWNLOAD_CLIENT_DATA="An error occurred while trying to download the client data files"
ERROR_IMPORT_DATABASE="An error occurred while trying to import the database files"
ERROR_COPY_CUSTOM_DBC="An error occurred while trying to copy custom dbc files"
ERROR_UPDATE_CONFIG="An error occurred while trying to update the config files"

if [[ ! -f $ROOT/config.sh ]]; then
    printf "${COLOR_RED}The config file is missing. Generating one with default values.${COLOR_END}\n"
    printf "${COLOR_RED}Make sure to edit it before running this script again.${COLOR_END}\n"

    echo "MYSQL_HOSTNAME=\"127.0.0.1\"" > $ROOT/config.sh
    echo "MYSQL_PORT=\"3306\"" >> $ROOT/config.sh
    echo "MYSQL_USERNAME=\"acore\"" >> $ROOT/config.sh
    echo "MYSQL_PASSWORD=\"acore\"" >> $ROOT/config.sh
    echo "MYSQL_DATABASES_AUTH=\"acore_auth\"" >> $ROOT/config.sh
    echo "MYSQL_DATABASES_CHARACTERS=\"acore_characters\"" >> $ROOT/config.sh
    echo "MYSQL_DATABASES_WORLD=\"acore_world\"" >> $ROOT/config.sh
    echo "SOURCE_REPOSITORY=\"https://github.com/azerothcore/azerothcore-wotlk.git\"" >> $ROOT/config.sh
    echo "SOURCE_BRANCH=\"master\"" >> $ROOT/config.sh
    echo "WORLD_NAME=\"AzerothCore\"" >> $ROOT/config.sh
    echo "WORLD_MOTD=\"Welcome to AzerothCore.\"" >> $ROOT/config.sh
    echo "WORLD_ID=\"1\"" >> $ROOT/config.sh
    echo "WORLD_ADDRESS=\"127.0.0.1\"" >> $ROOT/config.sh
    echo "WORLD_PORT=\"8085\"" >> $ROOT/config.sh
    echo "PRELOAD_MAP_GRIDS=\"false\"" >> $ROOT/config.sh
    echo "SET_CREATURES_ACTIVE=\"false\"" >> $ROOT/config.sh
    echo "PROGRESSION_ACTIVE_PATCH=\"21\"" >> $ROOT/config.sh
    echo "PROGRESSION_ICECROWN_CITADEL_AURA=\"0\"" >> $ROOT/config.sh
    echo "ACCOUNT_BOUND_ENABLED=\"false\"" >> $ROOT/config.sh
    echo "AHBOT_ENABLED=\"false\"" >> $ROOT/config.sh
    echo "AHBOT_MIN_ITEMS=\"200\"" >> $ROOT/config.sh
    echo "AHBOT_MAX_ITEMS=\"200\"" >> $ROOT/config.sh
    echo "APPRECIATION_ENABLED=\"false\"" >> $ROOT/config.sh
    echo "ASSISTANT_ENABLED=\"false\"" >> $ROOT/config.sh
    echo "GUILD_FUNDS_ENABLED=\"false\"" >> $ROOT/config.sh
    echo "GROUP_QUESTS_ENABLED=\"false\"" >> $ROOT/config.sh
    echo "JUNK_TO_GOLD_ENABLED=\"false\"" >> $ROOT/config.sh
    echo "LEARN_SPELLS_ENABLED=\"false\"" >> $ROOT/config.sh
    echo "PLAYER_BOTS_ENABLED=\"false\"" >> $ROOT/config.sh
    echo "PLAYER_BOTS_DATABASE=\"acore_playerbots\"" >> $ROOT/config.sh
    echo "PLAYER_BOTS_RANDOM_BOTS=\"500\"" >> $ROOT/config.sh
    echo "PLAYER_BOTS_RANDOM_BOT_ACCOUNTS=\"200\"" >> $ROOT/config.sh
    echo "RECRUIT_A_FRIEND_ENABLED=\"false\"" >> $ROOT/config.sh
    echo "WEEKEND_BONUS_ENABLED=\"false\"" >> $ROOT/config.sh
    echo "TELEGRAM_TOKEN=\"\"" >> $ROOT/config.sh
    echo "TELEGRAM_CHAT_ID=\"\"" >> $ROOT/config.sh
    exit $?
fi

source "$ROOT/config.sh"

if [[ $PROGRESSION_ACTIVE_PATCH -lt 12 ]]; then
    AHBOT_MAX_ITEM_LEVEL="92"
elif [[ $PROGRESSION_ACTIVE_PATCH -lt 17 ]]; then
    AHBOT_MAX_ITEM_LEVEL="164"
elif [[ $PROGRESSION_ACTIVE_PATCH -lt 18 ]]; then
    AHBOT_MAX_ITEM_LEVEL="213"
elif [[ $PROGRESSION_ACTIVE_PATCH -lt 19 ]]; then
    AHBOT_MAX_ITEM_LEVEL="226"
elif [[ $PROGRESSION_ACTIVE_PATCH -lt 20 ]]; then
    AHBOT_MAX_ITEM_LEVEL="245"
else
    AHBOT_MAX_ITEM_LEVEL="0"
fi

if [[ $PROGRESSION_ACTIVE_PATCH -lt 15 ]]; then
    GUILD_FUNDS_ENABLED="false"
fi

if [[ $PROGRESSION_ACTIVE_PATCH -lt 17 ]]; then
    ACCOUNT_BOUND_ENABLED="false"
    RECRUIT_A_FRIEND_ENABLED="false"
fi

function install_packages
{
    PACKAGES=("git" "cmake" "make" "gcc" "clang" "screen" "curl" "unzip" "g++" "libssl-dev" "libbz2-dev" "libreadline-dev" "libncurses-dev" "libboost1.74-all-dev" "libmysqlclient-dev" "mysql-client")

    for p in "${PACKAGES[@]}"; do
        if [[ $(dpkg-query -W -f='${Status}' $p 2>/dev/null | grep -c "ok installed") -eq 0 ]]; then
            INSTALL+=($p)
        fi
    done

    if [[ ${#INSTALL[@]} -gt 0 ]]; then
        clear

        if [[ $EUID != 0 ]]; then
            sudo apt-get --yes update
        else
            apt-get --yes update
        fi
        if [[ $? -ne 0 ]]; then
            notify_telegram "$ERROR_INSTALL_PACKAGES"
            exit $?
        fi

        if [[ $EUID != 0 ]]; then
            sudo apt-get --yes install ${INSTALL[*]}
        else
            apt-get --yes install ${INSTALL[*]}
        fi
        if [[ $? -ne 0 ]]; then
            notify_telegram "$ERROR_INSTALL_PACKAGES"
            exit $?
        fi
    fi
}

function get_source
{
    printf "${COLOR_GREEN}Downloading the source code...${COLOR_END}\n"

    if [[ ! -d $ROOT/source ]]; then
        git clone --recursive --depth 1 --branch $SOURCE_BRANCH $SOURCE_REPOSITORY $ROOT/source
        if [[ $? -ne 0 ]]; then
            notify_telegram "$ERROR_DOWNLOAD_SOURCE"
            exit $?
        fi
    else
        cd $ROOT/source

        git reset --hard origin/$SOURCE_BRANCH
        if [[ $? -ne 0 ]]; then
            notify_telegram "$ERROR_UPDATE_SOURCE"
            exit $?
        fi

        git pull
        if [[ $? -ne 0 ]]; then
            notify_telegram "$ERROR_UPDATE_SOURCE"
            exit $?
        fi

        git submodule update
        if [[ $? -ne 0 ]]; then
            notify_telegram "$ERROR_UPDATE_SOURCE"
            exit $?
        fi
    fi

    if [[ $1 == "both" ]] || [[ $1 == "world" ]]; then
        if [[ $ACCOUNT_BOUND_ENABLED == "true" ]]; then
            if [[ ! -d $ROOT/source/modules/mod-accountbound ]]; then
                git clone --depth 1 --branch master https://github.com/noisiver/mod-accountbound.git $ROOT/source/modules/mod-accountbound
                if [[ $? -ne 0 ]]; then
                    notify_telegram "$ERROR_DOWNLOAD_SOURCE_MODULE mod-accountbound"
                    exit $?
                fi
            else
                cd $ROOT/source/modules/mod-accountbound

                git reset --hard origin/master
                if [[ $? -ne 0 ]]; then
                    notify_telegram "$ERROR_UPDATE_SOURCE_MODULE mod-accountbound"
                    exit $?
                fi

                git pull
                if [[ $? -ne 0 ]]; then
                    notify_telegram "$ERROR_UPDATE_SOURCE_MODULE mod-accountbound"
                    exit $?
                fi
            fi
        else
            if [[ -d $ROOT/source/modules/mod-accountbound ]]; then
                rm -rf $ROOT/source/modules/mod-accountbound

                if [[ -d $ROOT/source/build ]]; then
                    rm -rf $ROOT/source/build
                fi
            fi
        fi

        if [[ $AHBOT_ENABLED == "true" ]]; then
            if [[ ! -d $ROOT/source/modules/mod-ah-bot ]]; then
                git clone --depth 1 --branch master https://github.com/azerothcore/mod-ah-bot.git $ROOT/source/modules/mod-ah-bot
                if [[ $? -ne 0 ]]; then
                    notify_telegram "$ERROR_DOWNLOAD_SOURCE_MODULE mod-ah-bot"
                    exit $?
                fi
            else
                cd $ROOT/source/modules/mod-ah-bot

                git reset --hard origin/master
                if [[ $? -ne 0 ]]; then
                    notify_telegram "$ERROR_UPDATE_SOURCE_MODULE mod-ah-bot"
                    exit $?
                fi

                git pull
                if [[ $? -ne 0 ]]; then
                    notify_telegram "$ERROR_UPDATE_SOURCE_MODULE mod-ah-bot"
                    exit $?
                fi
            fi
        else
            if [[ -d $ROOT/source/modules/mod-ah-bot ]]; then
                rm -rf $ROOT/source/modules/mod-ah-bot

                if [[ -d $ROOT/source/build ]]; then
                    rm -rf $ROOT/source/build
                fi
            fi
        fi

        : 'if [[ $APPRECIATION_ENABLED == "true" ]]; then
            if [[ ! -d $ROOT/source/modules/mod-appreciation ]]; then
                git clone --depth 1 --branch master https://github.com/noisiver/mod-appreciation.git $ROOT/source/modules/mod-appreciation
                if [[ $? -ne 0 ]]; then
                    notify_telegram "$ERROR_DOWNLOAD_SOURCE_MODULE mod-assistant"
                    exit $?
                fi
            else
                cd $ROOT/source/modules/mod-appreciation

                git reset --hard origin/master
                if [[ $? -ne 0 ]]; then
                    notify_telegram "$ERROR_UPDATE_SOURCE_MODULE mod-assistant"
                    exit $?
                fi

                git pull
                if [[ $? -ne 0 ]]; then
                    notify_telegram "$ERROR_UPDATE_SOURCE_MODULE mod-assistant"
                    exit $?
                fi
            fi
        else
            if [[ -d $ROOT/source/modules/mod-appreciation ]]; then
                rm -rf $ROOT/source/modules/mod-appreciation

                if [[ -d $ROOT/source/build ]]; then
                    rm -rf $ROOT/source/build
                fi
            fi
        fi'

        if [[ $ASSISTANT_ENABLED == "true" ]]; then
            if [[ ! -d $ROOT/source/modules/mod-assistant ]]; then
                git clone --depth 1 --branch master https://github.com/noisiver/mod-assistant.git $ROOT/source/modules/mod-assistant
                if [[ $? -ne 0 ]]; then
                    notify_telegram "$ERROR_DOWNLOAD_SOURCE_MODULE mod-assistant"
                    exit $?
                fi
            else
                cd $ROOT/source/modules/mod-assistant

                git reset --hard origin/master
                if [[ $? -ne 0 ]]; then
                    notify_telegram "$ERROR_UPDATE_SOURCE_MODULE mod-assistant"
                    exit $?
                fi

                git pull
                if [[ $? -ne 0 ]]; then
                    notify_telegram "$ERROR_UPDATE_SOURCE_MODULE mod-assistant"
                    exit $?
                fi
            fi
        else
            if [[ -d $ROOT/source/modules/mod-assistant ]]; then
                rm -rf $ROOT/source/modules/mod-assistant

                if [[ -d $ROOT/source/build ]]; then
                    rm -rf $ROOT/source/build
                fi
            fi
        fi

        if [[ $GUILD_FUNDS_ENABLED == "true" ]]; then
            if [[ ! -d $ROOT/source/modules/mod-guildfunds ]]; then
                git clone --depth 1 --branch master https://github.com/noisiver/mod-guildfunds.git $ROOT/source/modules/mod-guildfunds
                if [[ $? -ne 0 ]]; then
                    notify_telegram "$ERROR_DOWNLOAD_SOURCE_MODULE mod-guildfunds"
                    exit $?
                fi
            else
                cd $ROOT/source/modules/mod-guildfunds

                git reset --hard origin/master
                if [[ $? -ne 0 ]]; then
                    notify_telegram "$ERROR_UPDATE_SOURCE_MODULE mod-guildfunds"
                    exit $?
                fi

                git pull
                if [[ $? -ne 0 ]]; then
                    notify_telegram "$ERROR_UPDATE_SOURCE_MODULE mod-guildfunds"
                    exit $?
                fi
            fi
        else
            if [[ -d $ROOT/source/modules/mod-guildfunds ]]; then
                rm -rf $ROOT/source/modules/mod-guildfunds

                if [[ -d $ROOT/source/build ]]; then
                    rm -rf $ROOT/source/build
                fi
            fi
        fi

        if [[ $GROUP_QUESTS_ENABLED == "true" ]]; then
            if [[ ! -d $ROOT/source/modules/mod-groupquests ]]; then
                git clone --depth 1 --branch master https://github.com/noisiver/mod-groupquests.git $ROOT/source/modules/mod-groupquests
                if [[ $? -ne 0 ]]; then
                    notify_telegram "$ERROR_DOWNLOAD_SOURCE_MODULE mod-groupquests"
                    exit $?
                fi
            else
                cd $ROOT/source/modules/mod-groupquests

                git reset --hard origin/master
                if [[ $? -ne 0 ]]; then
                    notify_telegram "$ERROR_UPDATE_SOURCE_MODULE mod-groupquests"
                    exit $?
                fi

                git pull
                if [[ $? -ne 0 ]]; then
                    notify_telegram "$ERROR_UPDATE_SOURCE_MODULE mod-groupquests"
                    exit $?
                fi
            fi
        else
            if [[ -d $ROOT/source/modules/mod-groupquests ]]; then
                rm -rf $ROOT/source/modules/mod-groupquests

                if [[ -d $ROOT/source/build ]]; then
                    rm -rf $ROOT/source/build
                fi
            fi
        fi

        if [[ $JUNK_TO_GOLD_ENABLED == "true" ]]; then
            if [[ ! -d $ROOT/source/modules/mod-junk-to-gold ]]; then
                git clone --depth 1 --branch master https://github.com/noisiver/mod-junk-to-gold.git $ROOT/source/modules/mod-junk-to-gold
                if [[ $? -ne 0 ]]; then
                    notify_telegram "$ERROR_DOWNLOAD_SOURCE_MODULE mod-junk-to-gold"
                    exit $?
                fi
            else
                cd $ROOT/source/modules/mod-junk-to-gold

                git reset --hard origin/master
                if [[ $? -ne 0 ]]; then
                    notify_telegram "$ERROR_UPDATE_SOURCE_MODULE mod-junk-to-gold"
                    exit $?
                fi

                git pull
                if [[ $? -ne 0 ]]; then
                    notify_telegram "$ERROR_UPDATE_SOURCE_MODULE mod-junk-to-gold"
                    exit $?
                fi
            fi
        else
            if [[ -d $ROOT/source/modules/mod-junk-to-gold ]]; then
                rm -rf $ROOT/source/modules/mod-junk-to-gold

                if [[ -d $ROOT/source/build ]]; then
                    rm -rf $ROOT/source/build
                fi
            fi
        fi

        if [[ $LEARN_SPELLS_ENABLED == "true" ]]; then
            if [[ ! -d $ROOT/source/modules/mod-learnspells ]]; then
                if [[ $PROGRESSION_ACTIVE_PATCH -lt 21 ]]; then
                    git clone --depth 1 --branch progression https://github.com/noisiver/mod-learnspells.git $ROOT/source/modules/mod-learnspells
                else
                    git clone --depth 1 --branch master https://github.com/noisiver/mod-learnspells.git $ROOT/source/modules/mod-learnspells
                fi
                if [[ $? -ne 0 ]]; then
                    notify_telegram "$ERROR_DOWNLOAD_SOURCE_MODULE mod-learnspells"
                    exit $?
                fi
            else
                cd $ROOT/source/modules/mod-learnspells

                if [[ $PROGRESSION_ACTIVE_PATCH -lt 21 ]]; then
                    git reset --hard origin/progression
                else
                    git reset --hard origin/master
                fi
                if [[ $? -ne 0 ]]; then
                    notify_telegram "$ERROR_UPDATE_SOURCE_MODULE mod-learnspells"
                    exit $?
                fi

                git pull
                if [[ $? -ne 0 ]]; then
                    notify_telegram "$ERROR_UPDATE_SOURCE_MODULE mod-learnspells"
                    exit $?
                fi
            fi
        else
            if [[ -d $ROOT/source/modules/mod-learnspells ]]; then
                rm -rf $ROOT/source/modules/mod-learnspells

                if [[ -d $ROOT/source/build ]]; then
                    rm -rf $ROOT/source/build
                fi
            fi
        fi

        if [[ $PLAYER_BOTS_ENABLED == "true" ]]; then
            if [[ ! -d $ROOT/source/modules/mod-playerbots ]]; then
                git clone --depth 1 --branch master https://github.com/liyunfan1223/mod-playerbots.git $ROOT/source/modules/mod-playerbots
                if [[ $? -ne 0 ]]; then
                    notify_telegram ""$ERROR_DOWNLOAD_SOURCE_MODULE" mod-playerbots"
                    exit $?
                fi
            else
                cd $ROOT/source/modules/mod-playerbots

                git reset --hard origin/master
                if [[ $? -ne 0 ]]; then
                    notify_telegram ""$ERROR_UPDATE_SOURCE_MODULE" mod-playerbots"
                    exit $?
                fi

                git pull
                if [[ $? -ne 0 ]]; then
                    notify_telegram ""$ERROR_UPDATE_SOURCE_MODULE" mod-playerbots"
                    exit $?
                fi
            fi
        else
            if [[ -d $ROOT/source/modules/mod-playerbots ]]; then
                rm -rf $ROOT/source/modules/mod-playerbots

                if [[ -d $ROOT/source/build ]]; then
                    rm -rf $ROOT/source/build
                fi
            fi
        fi

        if [[ $RECRUIT_A_FRIEND_ENABLED == "true" ]]; then
            if [[ ! -d $ROOT/source/modules/mod-recruitafriend ]]; then
                git clone --depth 1 --branch master https://github.com/noisiver/mod-recruitafriend.git $ROOT/source/modules/mod-recruitafriend
                if [[ $? -ne 0 ]]; then
                    notify_telegram "$ERROR_DOWNLOAD_SOURCE_MODULE mod-recruitafriend"
                    exit $?
                fi
            else
                cd $ROOT/source/modules/mod-recruitafriend

                git reset --hard origin/master
                if [[ $? -ne 0 ]]; then
                    notify_telegram "$ERROR_UPDATE_SOURCE_MODULE mod-recruitafriend"
                    exit $?
                fi

                git pull
                if [[ $? -ne 0 ]]; then
                    notify_telegram "$ERROR_UPDATE_SOURCE_MODULE mod-recruitafriend"
                    exit $?
                fi
            fi
        else
            if [[ -d $ROOT/source/modules/mod-recruitafriend ]]; then
                rm -rf $ROOT/source/modules/mod-recruitafriend

                if [[ -d $ROOT/source/build ]]; then
                    rm -rf $ROOT/source/build
                fi
            fi
        fi

        if [[ $WEEKEND_BONUS_ENABLED == "true" ]]; then
            if [[ ! -d $ROOT/source/modules/mod-weekendbonus ]]; then
                git clone --depth 1 --branch master https://github.com/noisiver/mod-weekendbonus.git $ROOT/source/modules/mod-weekendbonus
                if [[ $? -ne 0 ]]; then
                    notify_telegram "$ERROR_DOWNLOAD_SOURCE_MODULE mod-weekendbonus"
                    exit $?
                fi
            else
                cd $ROOT/source/modules/mod-weekendbonus

                git reset --hard origin/master
                if [[ $? -ne 0 ]]; then
                    notify_telegram "$ERROR_UPDATE_SOURCE_MODULE mod-weekendbonus"
                    exit $?
                fi

                git pull
                if [[ $? -ne 0 ]]; then
                    notify_telegram "$ERROR_UPDATE_SOURCE_MODULE mod-weekendbonus"
                    exit $?
                fi
            fi
        else
            if [[ -d $ROOT/source/modules/mod-weekendbonus ]]; then
                rm -rf $ROOT/source/modules/mod-weekendbonus

                if [[ -d $ROOT/source/build ]]; then
                    rm -rf $ROOT/source/build
                fi
            fi
        fi
    fi

    printf "${COLOR_GREEN}Finished downloading the source code...${COLOR_END}\n"
}

function compile_source
{
    printf "${COLOR_GREEN}Compiling the source code...${COLOR_END}\n"

    mkdir -p $ROOT/source/build && cd $_

    if [[ $1 == "auth" ]]; then
        APPS_BUILD="auth-only"
    elif [[ $1 == "world" ]]; then
        APPS_BUILD="world-only"
    else
        APPS_BUILD="all"
    fi

    for i in {1..2}; do
        cmake ../ -DCMAKE_INSTALL_PREFIX=$ROOT/source -DCMAKE_C_COMPILER=/usr/bin/clang -DCMAKE_CXX_COMPILER=/usr/bin/clang++ -DWITH_WARNINGS=1 -DSCRIPTS=static -DAPPS_BUILD="$APPS_BUILD"
        if [[ $? -ne 0 ]]; then
            notify_telegram "$ERROR_COMPILE_SOURCE"
            exit $?
        fi

        make -j $(nproc)
        if [[ $? -ne 0 ]]; then
            if [[ $i == 1 ]]; then
                make clean
            else
                notify_telegram "$ERROR_COMPILE_SOURCE"
                exit $?
            fi
        else
            break
        fi
    done

    make install
    if [[ $? -ne 0 ]]; then
        notify_telegram "$ERROR_COMPILE_SOURCE"
        exit $?
    fi

    echo "#!/bin/bash" > $ROOT/source/bin/start.sh
    echo "#!/bin/bash" > $ROOT/source/bin/stop.sh

    if [[ $1 == "both" ]] || [[ $1 == "auth" ]]; then
        echo "screen -AmdS auth ./auth.sh" >> $ROOT/source/bin/start.sh
        echo "screen -X -S \"auth\" quit" >> $ROOT/source/bin/stop.sh

        echo "#!/bin/bash" > $ROOT/source/bin/auth.sh
        echo "while :; do" >> $ROOT/source/bin/auth.sh
        echo "  ./authserver" >> $ROOT/source/bin/auth.sh
        echo "  sleep 5" >> $ROOT/source/bin/auth.sh
        echo "done" >> $ROOT/source/bin/auth.sh

        chmod +x $ROOT/source/bin/auth.sh
    else
        if [[ -f $ROOT/source/bin/auth.sh ]]; then
            rm -rf $ROOT/source/bin/auth.sh
        fi
    fi

    if [[ $1 == "both" ]] || [[ $1 == "world" ]]; then
        echo "TIME=\$(date +%s)" >> $ROOT/source/bin/start.sh
        echo "screen -L -Logfile \$TIME.log -AmdS world-$WORLD_ID ./world.sh" >> $ROOT/source/bin/start.sh
        echo "screen -X -S \"world-$WORLD_ID\" quit" >> $ROOT/source/bin/stop.sh

        echo "#!/bin/bash" > $ROOT/source/bin/world.sh
        echo "while :; do" >> $ROOT/source/bin/world.sh
        echo "  ./worldserver" >> $ROOT/source/bin/world.sh
        echo "  if [[ \$? == 0 ]]; then" >> $ROOT/source/bin/world.sh
        echo "    break" >> $ROOT/source/bin/world.sh
        echo "  fi" >> $ROOT/source/bin/world.sh
        echo "  sleep 5" >> $ROOT/source/bin/world.sh
        echo "done" >> $ROOT/source/bin/world.sh

        chmod +x $ROOT/source/bin/world.sh
    else
        if [[ -f $ROOT/source/bin/world.sh ]]; then
            rm -rf $ROOT/source/bin/world.sh
        fi
    fi

    chmod +x $ROOT/source/bin/start.sh
    chmod +x $ROOT/source/bin/stop.sh

    printf "${COLOR_GREEN}Finished compiling the source code...${COLOR_END}\n"
}

function get_client_files
{
    if [[ $1 == "both" ]] || [[ $1 == "world" ]]; then
        if [[ ! -f $ROOT/client.version ]]; then
            VERSION="0"
        else
            VERSION=$(<$ROOT/client.version)
        fi

        if [[ ! -d $ROOT/source/bin/Cameras ]] || [[ ! -d $ROOT/source/bin/dbc ]] || [[ ! -d $ROOT/source/bin/maps ]] || [[ ! -d $ROOT/source/bin/mmaps ]] || [[ ! -d $ROOT/source/bin/vmaps ]]; then
            VERSION=0
        fi

        AVAILABLE_VERSION=$(git ls-remote --tags --sort="v:refname" https://github.com/wowgaming/client-data.git | tail -n1 | cut --delimiter='/' --fields=3 | sed 's/v//')

        if [[ $VERSION != $AVAILABLE_VERSION ]]; then
            printf "${COLOR_GREEN}Downloading the client data files...${COLOR_END}\n"

            if [[ -d $ROOT/source/bin/Cameras ]]; then
                rm -rf $ROOT/source/bin/Cameras
            fi
            if [[ -d $ROOT/source/bin/dbc ]]; then
                rm -rf $ROOT/source/bin/dbc
            fi
            if [[ -d $ROOT/source/bin/maps ]]; then
                rm -rf $ROOT/source/bin/maps
            fi
            if [[ -d $ROOT/source/bin/mmaps ]]; then
                rm -rf $ROOT/source/bin/mmaps
            fi
            if [[ -d $ROOT/source/bin/vmaps ]]; then
                rm -rf $ROOT/source/bin/vmaps
            fi

            curl -f -L https://github.com/wowgaming/client-data/releases/download/v${AVAILABLE_VERSION}/data.zip -o $ROOT/source/bin/data.zip
            if [[ $? -ne 0 ]]; then
                rm -rf $ROOT/source/bin/data.zip
                notify_telegram "$ERROR_DOWNLOAD_CLIENT_DATA"
                exit $?
            fi

            unzip -o "$ROOT/source/bin/data.zip" -d "$ROOT/source/bin/"
            if [[ $? -ne 0 ]]; then
                notify_telegram "$ERROR_DOWNLOAD_CLIENT_DATA"
                exit $?
            fi

            rm -rf $ROOT/source/bin/data.zip

            echo $AVAILABLE_VERSION > $ROOT/client.version

            printf "${COLOR_GREEN}Finished downloading the client data files...${COLOR_END}\n"
        fi
    fi
}

function import_database_files
{
    printf "${COLOR_GREEN}Importing the database files...${COLOR_END}\n"

    MYSQL_CNF="$ROOT/mysql.cnf"
    echo "[client]" > $MYSQL_CNF
    echo "host=\"$MYSQL_HOSTNAME\"" >> $MYSQL_CNF
    echo "port=\"$MYSQL_PORT\"" >> $MYSQL_CNF
    echo "user=\"$MYSQL_USERNAME\"" >> $MYSQL_CNF
    echo "password=\"$MYSQL_PASSWORD\"" >> $MYSQL_CNF

    if [[ -z `mysql --defaults-extra-file=$MYSQL_CNF --skip-column-names -e "SHOW DATABASES LIKE '$MYSQL_DATABASES_AUTH'"` ]]; then
        printf "${COLOR_RED}The database named $MYSQL_DATABASES_AUTH is inaccessible by the user named $MYSQL_USERNAME.${COLOR_END}\n"
        notify_telegram "$ERROR_IMPORT_DATABASE"
        rm -rf $MYSQL_CNF
        exit $?
    fi

    if [[ $1 == "world" ]] || [[ $1 == "both" ]]; then
        if [[ -z `mysql --defaults-extra-file=$MYSQL_CNF --skip-column-names -e "SHOW DATABASES LIKE '$MYSQL_DATABASES_CHARACTERS'"` ]]; then
            printf "${COLOR_RED}The database named $MYSQL_DATABASES_CHARACTERS is inaccessible by the user named $MYSQL_USERNAME.${COLOR_END}\n"
            notify_telegram "$ERROR_IMPORT_DATABASE"
            rm -rf $MYSQL_CNF
            exit $?
        fi

        if [[ -z `mysql --defaults-extra-file=$MYSQL_CNF --skip-column-names -e "SHOW DATABASES LIKE '$MYSQL_DATABASES_WORLD'"` ]] && [[ $1 == "world" || $1 == "both" ]]; then
            printf "${COLOR_RED}The database named $MYSQL_DATABASES_WORLD is inaccessible by the user named $MYSQL_USERNAME.${COLOR_END}\n"
            notify_telegram "$ERROR_IMPORT_DATABASE"
            rm -rf $MYSQL_CNF
            exit $?
        fi

        if [[ $PLAYER_BOTS_ENABLED == "true" ]]; then
            if [[ -z `mysql --defaults-extra-file=$MYSQL_CNF --skip-column-names -e "SHOW DATABASES LIKE '$PLAYER_BOTS_DATABASE'"` ]] && [[ $1 == "world" || $1 == "both" ]]; then
                printf "${COLOR_RED}The database named $PLAYER_BOTS_DATABASE is inaccessible by the user named $MYSQL_USERNAME.${COLOR_END}\n"
                notify_telegram $ERROR_IMPORT_DATABASE
                rm -rf $MYSQL_CNF
                exit $?
            fi
        fi
    fi

    if [[ ! -d $ROOT/source/data/sql/base/db_auth ]] || [[ ! -d $ROOT/source/data/sql/updates/db_auth ]] || [[ ! -d $ROOT/source/data/sql/custom/db_auth ]]; then
        printf "${COLOR_RED}There are no database files where there should be.${COLOR_END}\n"
        printf "${COLOR_RED}Please make sure to install the server first.${COLOR_END}\n"
        notify_telegram "$ERROR_IMPORT_DATABASE"
        rm -rf $MYSQL_CNF
        exit $?
    fi

    if [[ $1 == "world" ]] || [[ $1 == "both" ]]; then
        if [[ ! -d $ROOT/source/data/sql/base/db_characters ]] || [[ ! -d $ROOT/source/data/sql/updates/db_characters ]] || [[ ! -d $ROOT/source/data/sql/custom/db_characters ]] || [[ ! -d $ROOT/source/data/sql/base/db_world ]] || [[ ! -d $ROOT/source/data/sql/updates/db_world ]] || [[ ! -d $ROOT/source/data/sql/custom/db_world ]]; then
            printf "${COLOR_RED}There are no database files where there should be.${COLOR_END}\n"
            printf "${COLOR_RED}Please make sure to install the server first.${COLOR_END}\n"
            notify_telegram "$ERROR_IMPORT_DATABASE"
            rm -rf $MYSQL_CNF
            exit $?
        fi
    fi

    if [[ ! -d $ROOT/sql/auth ]]; then
        mkdir -p $ROOT/sql/auth
        if [[ $? -ne 0 ]]; then
            notify_telegram "$ERROR_IMPORT_DATABASE"
            exit $?
        fi
    fi

    if [[ $1 == "world" ]] || [[ $1 == "both" ]]; then
        if [[ ! -d $ROOT/sql/characters ]]; then
            mkdir -p $ROOT/sql/characters
            if [[ $? -ne 0 ]]; then
                notify_telegram "$ERROR_IMPORT_DATABASE"
                exit $?
            fi
        fi

        if [[ ! -d $ROOT/sql/world ]]; then
            mkdir -p $ROOT/sql/world
            if [[ $? -ne 0 ]]; then
                notify_telegram "$ERROR_IMPORT_DATABASE"
                exit $?
            fi
        fi
    fi

    if [[ `ls -1 $ROOT/source/data/sql/base/db_auth/*.sql 2>/dev/null | wc -l` -gt 0 ]]; then
        for f in $ROOT/source/data/sql/base/db_auth/*.sql; do
            if [[ ! -z `mysql --defaults-extra-file=$MYSQL_CNF --skip-column-names $MYSQL_DATABASES_AUTH -e "SHOW TABLES LIKE '$(basename $f .sql)'"` ]]; then
                printf "${COLOR_ORANGE}Skipping "$(basename $f)"${COLOR_END}\n"
                continue;
            fi

            printf "${COLOR_ORANGE}Importing "$(basename $f)"${COLOR_END}\n"
            mysql --defaults-extra-file=$MYSQL_CNF $MYSQL_DATABASES_AUTH < $f
            if [[ $? -ne 0 ]]; then
                notify_telegram "$ERROR_IMPORT_DATABASE"
                rm -rf $MYSQL_CNF
                exit $?
            fi
        done
    else
        printf "${COLOR_RED}The required files for the auth database are missing.${COLOR_END}\n"
        printf "${COLOR_RED}Please make sure to install the server first.${COLOR_END}\n"
    fi

    if [[ `ls -1 $ROOT/source/data/sql/updates/db_auth/*.sql 2>/dev/null | wc -l` -gt 0 ]]; then
        for f in $ROOT/source/data/sql/updates/db_auth/*.sql; do
            FILENAME=$(basename $f)
            HASH=($(sha1sum $f))

            if [[ ! -z `mysql --defaults-extra-file=$MYSQL_CNF --skip-column-names $MYSQL_DATABASES_AUTH -e "SELECT * FROM updates WHERE name='$FILENAME' AND hash='${HASH^^}'"` ]]; then
                printf "${COLOR_ORANGE}Skipping "$(basename $f)"${COLOR_END}\n"
                continue;
            fi

            printf "${COLOR_ORANGE}Importing "$(basename $f)"${COLOR_END}\n"
            mysql --defaults-extra-file=$MYSQL_CNF $MYSQL_DATABASES_AUTH < $f
            if [[ $? -ne 0 ]]; then
                notify_telegram "$ERROR_IMPORT_DATABASE"
                rm -rf $MYSQL_CNF
                exit $?
            fi

            mysql --defaults-extra-file=$MYSQL_CNF $MYSQL_DATABASES_AUTH -e "DELETE FROM updates WHERE name='$(basename $f)';INSERT INTO updates (name, hash, state) VALUES ('$FILENAME', '${HASH^^}', 'RELEASED')"
            if [[ $? -ne 0 ]]; then
                notify_telegram "$ERROR_IMPORT_DATABASE"
                rm -rf $MYSQL_CNF
                exit $?
            fi
        done
    fi

    if [[ `ls -1 $ROOT/source/data/sql/custom/db_auth/*.sql 2>/dev/null | wc -l` -gt 0 ]]; then
        for f in $ROOT/source/data/sql/custom/db_auth/*.sql; do
            FILENAME=$(basename $f)
            HASH=($(sha1sum $f))

            if [[ ! -z `mysql --defaults-extra-file=$MYSQL_CNF --skip-column-names $MYSQL_DATABASES_AUTH -e "SELECT * FROM updates WHERE name='$FILENAME' AND hash='${HASH^^}'"` ]]; then
                printf "${COLOR_ORANGE}Skipping "$(basename $f)"${COLOR_END}\n"
                continue;
            fi

            printf "${COLOR_ORANGE}Importing "$(basename $f)"${COLOR_END}\n"
            mysql --defaults-extra-file=$MYSQL_CNF $MYSQL_DATABASES_AUTH < $f
            if [[ $? -ne 0 ]]; then
                notify_telegram "$ERROR_IMPORT_DATABASE"
                rm -rf $MYSQL_CNF
                exit $?
            fi

            mysql --defaults-extra-file=$MYSQL_CNF $MYSQL_DATABASES_AUTH -e "DELETE FROM updates WHERE name='$(basename $f)';INSERT INTO updates (name, hash, state) VALUES ('$FILENAME', '${HASH^^}', 'RELEASED')"
            if [[ $? -ne 0 ]]; then
                notify_telegram "$ERROR_IMPORT_DATABASE"
                rm -rf $MYSQL_CNF
                exit $?
            fi
        done
    fi

    if [[ `ls -1 $ROOT/sql/auth/*.sql 2>/dev/null | wc -l` -gt 0 ]]; then
        for f in $ROOT/sql/auth/*.sql; do
            printf "${COLOR_ORANGE}Importing "$(basename $f)"${COLOR_END}\n"
            mysql --defaults-extra-file=$MYSQL_CNF $MYSQL_DATABASES_AUTH < $f
            if [[ $? -ne 0 ]]; then
                notify_telegram "$ERROR_IMPORT_DATABASE"
                rm -rf $MYSQL_CNF
                exit $?
            fi
        done
    fi

    if [[ $1 == "world" ]] || [[ $1 == "both" ]]; then
        if [[ `ls -1 $ROOT/source/data/sql/base/db_characters/*.sql 2>/dev/null | wc -l` -gt 0 ]]; then
            for f in $ROOT/source/data/sql/base/db_characters/*.sql; do
                if [[ ! -z `mysql --defaults-extra-file=$MYSQL_CNF --skip-column-names $MYSQL_DATABASES_CHARACTERS -e "SHOW TABLES LIKE '$(basename $f .sql)'"` ]]; then
                    printf "${COLOR_ORANGE}Skipping "$(basename $f)"${COLOR_END}\n"
                    continue;
                fi

                printf "${COLOR_ORANGE}Importing "$(basename $f)"${COLOR_END}\n"
                mysql --defaults-extra-file=$MYSQL_CNF $MYSQL_DATABASES_CHARACTERS < $f
                if [[ $? -ne 0 ]]; then
                    notify_telegram "$ERROR_IMPORT_DATABASE"
                    rm -rf $MYSQL_CNF
                    exit $?
                fi
            done
        else
            printf "${COLOR_RED}The required files for the characters database are missing.${COLOR_END}\n"
            printf "${COLOR_RED}Please make sure to install the server first.${COLOR_END}\n"
        fi

        if [[ `ls -1 $ROOT/source/data/sql/updates/db_characters/*.sql 2>/dev/null | wc -l` -gt 0 ]]; then
            for f in $ROOT/source/data/sql/updates/db_characters/*.sql; do
                FILENAME=$(basename $f)
                HASH=($(sha1sum $f))

                if [[ ! -z `mysql --defaults-extra-file=$MYSQL_CNF --skip-column-names $MYSQL_DATABASES_CHARACTERS -e "SELECT * FROM updates WHERE name='$FILENAME' AND hash='${HASH^^}'"` ]]; then
                    printf "${COLOR_ORANGE}Skipping "$(basename $f)"${COLOR_END}\n"
                    continue;
                fi

                printf "${COLOR_ORANGE}Importing "$(basename $f)"${COLOR_END}\n"
                mysql --defaults-extra-file=$MYSQL_CNF $MYSQL_DATABASES_CHARACTERS < $f
                if [[ $? -ne 0 ]]; then
                    notify_telegram "$ERROR_IMPORT_DATABASE"
                    rm -rf $MYSQL_CNF
                    exit $?
                fi

                mysql --defaults-extra-file=$MYSQL_CNF $MYSQL_DATABASES_CHARACTERS -e "DELETE FROM updates WHERE name='$(basename $f)';INSERT INTO updates (name, hash, state) VALUES ('$FILENAME', '${HASH^^}', 'RELEASED')"
                if [[ $? -ne 0 ]]; then
                    notify_telegram "$ERROR_IMPORT_DATABASE"
                    rm -rf $MYSQL_CNF
                    exit $?
                fi
            done
        fi

        if [[ `ls -1 $ROOT/source/data/sql/custom/db_characters/*.sql 2>/dev/null | wc -l` -gt 0 ]]; then
            for f in $ROOT/source/data/sql/custom/db_characters/*.sql; do
                FILENAME=$(basename $f)
                HASH=($(sha1sum $f))

                if [[ ! -z `mysql --defaults-extra-file=$MYSQL_CNF --skip-column-names $MYSQL_DATABASES_CHARACTERS -e "SELECT * FROM updates WHERE name='$FILENAME' AND hash='${HASH^^}'"` ]]; then
                    printf "${COLOR_ORANGE}Skipping "$(basename $f)"${COLOR_END}\n"
                    continue;
                fi

                printf "${COLOR_ORANGE}Importing "$(basename $f)"${COLOR_END}\n"
                mysql --defaults-extra-file=$MYSQL_CNF $MYSQL_DATABASES_CHARACTERS < $f
                if [[ $? -ne 0 ]]; then
                    notify_telegram "$ERROR_IMPORT_DATABASE"
                    rm -rf $MYSQL_CNF
                    exit $?
                fi

                mysql --defaults-extra-file=$MYSQL_CNF $MYSQL_DATABASES_CHARACTERS -e "DELETE FROM updates WHERE name='$(basename $f)';INSERT INTO updates (name, hash, state) VALUES ('$FILENAME', '${HASH^^}', 'RELEASED')"
                if [[ $? -ne 0 ]]; then
                    notify_telegram "$ERROR_IMPORT_DATABASE"
                    rm -rf $MYSQL_CNF
                    exit $?
                fi
            done
        fi

        if [[ `ls -1 $ROOT/source/data/sql/base/db_world/*.sql 2>/dev/null | wc -l` -gt 0 ]]; then
            for f in $ROOT/source/data/sql/base/db_world/*.sql; do
                if [[ ! -z `mysql --defaults-extra-file=$MYSQL_CNF --skip-column-names $MYSQL_DATABASES_WORLD -e "SHOW TABLES LIKE '$(basename $f .sql)'"` ]]; then
                    printf "${COLOR_ORANGE}Skipping "$(basename $f)"${COLOR_END}\n"
                    continue;
                fi

                printf "${COLOR_ORANGE}Importing "$(basename $f)"${COLOR_END}\n"
                mysql --defaults-extra-file=$MYSQL_CNF $MYSQL_DATABASES_WORLD < $f
                if [[ $? -ne 0 ]]; then
                    notify_telegram "$ERROR_IMPORT_DATABASE"
                    rm -rf $MYSQL_CNF
                    exit $?
                fi
            done
        else
            printf "${COLOR_RED}The required files for the world database are missing.${COLOR_END}\n"
            printf "${COLOR_RED}Please make sure to install the server first.${COLOR_END}\n"
        fi

        if [[ `ls -1 $ROOT/source/data/sql/updates/db_world/*.sql 2>/dev/null | wc -l` -gt 0 ]]; then
            for f in $ROOT/source/data/sql/updates/db_world/*.sql; do
                FILENAME=$(basename $f)
                HASH=($(sha1sum $f))

                if [[ ! -z `mysql --defaults-extra-file=$MYSQL_CNF --skip-column-names $MYSQL_DATABASES_WORLD -e "SELECT * FROM updates WHERE name='$FILENAME' AND hash='${HASH^^}'"` ]]; then
                    printf "${COLOR_ORANGE}Skipping "$(basename $f)"${COLOR_END}\n"
                    continue;
                fi

                printf "${COLOR_ORANGE}Importing "$(basename $f)"${COLOR_END}\n"
                mysql --defaults-extra-file=$MYSQL_CNF $MYSQL_DATABASES_WORLD < $f
                if [[ $? -ne 0 ]]; then
                    notify_telegram "$ERROR_IMPORT_DATABASE"
                    rm -rf $MYSQL_CNF
                    exit $?
                fi

                mysql --defaults-extra-file=$MYSQL_CNF $MYSQL_DATABASES_WORLD -e "DELETE FROM updates WHERE name='$(basename $f)';INSERT INTO updates (name, hash, state) VALUES ('$FILENAME', '${HASH^^}', 'RELEASED')"
                if [[ $? -ne 0 ]]; then
                    notify_telegram "$ERROR_IMPORT_DATABASE"
                    rm -rf $MYSQL_CNF
                    exit $?
                fi
            done
        fi

        if [[ `ls -1 $ROOT/source/data/sql/custom/db_world/*.sql 2>/dev/null | wc -l` -gt 0 ]]; then
            for f in $ROOT/source/data/sql/custom/db_world/*.sql; do
                FILENAME=$(basename $f)
                HASH=($(sha1sum $f))

                if [[ ! -z `mysql --defaults-extra-file=$MYSQL_CNF --skip-column-names $MYSQL_DATABASES_WORLD -e "SELECT * FROM updates WHERE name='$FILENAME' AND hash='${HASH^^}'"` ]]; then
                    printf "${COLOR_ORANGE}Skipping "$(basename $f)"${COLOR_END}\n"
                    continue;
                fi

                printf "${COLOR_ORANGE}Importing "$(basename $f)"${COLOR_END}\n"
                mysql --defaults-extra-file=$MYSQL_CNF $MYSQL_DATABASES_WORLD < $f
                if [[ $? -ne 0 ]]; then
                    notify_telegram "$ERROR_IMPORT_DATABASE"
                    rm -rf $MYSQL_CNF
                    exit $?
                fi

                mysql --defaults-extra-file=$MYSQL_CNF $MYSQL_DATABASES_WORLD -e "DELETE FROM updates WHERE name='$(basename $f)';INSERT INTO updates (name, hash, state) VALUES ('$FILENAME', '${HASH^^}', 'RELEASED')"
                if [[ $? -ne 0 ]]; then
                    notify_telegram "$ERROR_IMPORT_DATABASE"
                    rm -rf $MYSQL_CNF
                    exit $?
                fi
            done
        fi

        if [[ $ACCOUNT_BOUND_ENABLED == "true" ]]; then
            if [[ ! -d $ROOT/source/modules/mod-accountbound/data/sql/db-auth/base ]] || [[ ! -d $ROOT/source/modules/mod-accountbound/data/sql/db-world/base ]]; then
                printf "${COLOR_RED}The account bound module is enabled but the files aren't where they should be.${COLOR_END}\n"
                printf "${COLOR_RED}Please make sure to install the server first.${COLOR_END}\n"
                notify_telegram "$ERROR_IMPORT_DATABASE"
                exit $?
            fi

            if [[ `ls -1 $ROOT/source/modules/mod-accountbound/data/sql/db-auth/base/*.sql 2>/dev/null | wc -l` -gt 0 ]]; then
                for f in $ROOT/source/modules/mod-accountbound/data/sql/db-auth/base/*.sql; do
                    FILENAME=$(basename $f)
                    HASH=($(sha1sum $f))

                    if [[ ! -z `mysql --defaults-extra-file=$MYSQL_CNF --skip-column-names $MYSQL_DATABASES_AUTH -e "SELECT * FROM updates WHERE name='$FILENAME' AND hash='${HASH^^}'"` ]]; then
                        printf "${COLOR_ORANGE}Skipping "$(basename $f)"${COLOR_END}\n"
                        continue;
                    fi

                    printf "${COLOR_ORANGE}Importing "$(basename $f)"${COLOR_END}\n"
                    mysql --defaults-extra-file=$MYSQL_CNF $MYSQL_DATABASES_AUTH < $f
                    if [[ $? -ne 0 ]]; then
                        notify_telegram "$ERROR_IMPORT_DATABASE"
                        rm -rf $MYSQL_CNF
                        exit $?
                    fi

                    mysql --defaults-extra-file=$MYSQL_CNF $MYSQL_DATABASES_AUTH -e "DELETE FROM updates WHERE name='$(basename $f)';INSERT INTO updates (name, hash, state) VALUES ('$FILENAME', '${HASH^^}', 'CUSTOM')"
                    if [[ $? -ne 0 ]]; then
                        notify_telegram "$ERROR_IMPORT_DATABASE"
                        rm -rf $MYSQL_CNF
                        exit $?
                    fi
                done
            fi

            if [[ `ls -1 $ROOT/source/modules/mod-accountbound/data/sql/db-world/base/*.sql 2>/dev/null | wc -l` -gt 0 ]]; then
                for f in $ROOT/source/modules/mod-accountbound/data/sql/db-world/base/*.sql; do
                    FILENAME=$(basename $f)
                    HASH=($(sha1sum $f))

                    if [[ ! -z `mysql --defaults-extra-file=$MYSQL_CNF --skip-column-names $MYSQL_DATABASES_WORLD -e "SELECT * FROM updates WHERE name='$FILENAME' AND hash='${HASH^^}'"` ]]; then
                        printf "${COLOR_ORANGE}Skipping "$(basename $f)"${COLOR_END}\n"
                        continue;
                    fi

                    printf "${COLOR_ORANGE}Importing "$(basename $f)"${COLOR_END}\n"
                    mysql --defaults-extra-file=$MYSQL_CNF $MYSQL_DATABASES_WORLD < $f
                    if [[ $? -ne 0 ]]; then
                        notify_telegram "$ERROR_IMPORT_DATABASE"
                        rm -rf $MYSQL_CNF
                        exit $?
                    fi

                    mysql --defaults-extra-file=$MYSQL_CNF $MYSQL_DATABASES_WORLD -e "DELETE FROM updates WHERE name='$(basename $f)';INSERT INTO updates (name, hash, state) VALUES ('$FILENAME', '${HASH^^}', 'CUSTOM')"
                    if [[ $? -ne 0 ]]; then
                        notify_telegram "$ERROR_IMPORT_DATABASE"
                        rm -rf $MYSQL_CNF
                        exit $?
                    fi
                done
            fi
        fi

        if [[ $AHBOT_ENABLED == "true" ]]; then
            if [[ ! -d $ROOT/source/modules/mod-ah-bot/data/sql/db-world/base ]]; then
                printf "${COLOR_RED}The auction house bot module is enabled but the files aren't where they should be.${COLOR_END}\n"
                printf "${COLOR_RED}Please make sure to install the server first.${COLOR_END}\n"
                notify_telegram "$ERROR_IMPORT_DATABASE"
                exit $?
            fi

            if [[ `ls -1 $ROOT/source/modules/mod-ah-bot/data/sql/db-world/base/*.sql 2>/dev/null | wc -l` -gt 0 ]]; then
                for f in $ROOT/source/modules/mod-ah-bot/data/sql/db-world/base/*.sql; do
                    FILENAME=$(basename $f)
                    HASH=($(sha1sum $f))

                    if [[ ! -z `mysql --defaults-extra-file=$MYSQL_CNF --skip-column-names $MYSQL_DATABASES_WORLD -e "SELECT * FROM updates WHERE name='$FILENAME' AND hash='${HASH^^}'"` ]]; then
                        printf "${COLOR_ORANGE}Skipping "$(basename $f)"${COLOR_END}\n"
                        continue;
                    fi

                    printf "${COLOR_ORANGE}Importing "$(basename $f)"${COLOR_END}\n"
                    mysql --defaults-extra-file=$MYSQL_CNF $MYSQL_DATABASES_WORLD < $f
                    if [[ $? -ne 0 ]]; then
                        notify_telegram "$ERROR_IMPORT_DATABASE"
                        rm -rf $MYSQL_CNF
                        exit $?
                    fi

                    mysql --defaults-extra-file=$MYSQL_CNF $MYSQL_DATABASES_WORLD -e "DELETE FROM updates WHERE name='$(basename $f)';INSERT INTO updates (name, hash, state) VALUES ('$FILENAME', '${HASH^^}', 'CUSTOM')"
                    if [[ $? -ne 0 ]]; then
                        notify_telegram "$ERROR_IMPORT_DATABASE"
                        rm -rf $MYSQL_CNF
                        exit $?
                    fi
                done
            fi

            mysql --defaults-extra-file=$MYSQL_CNF $MYSQL_DATABASES_WORLD -e "UPDATE mod_auctionhousebot SET minitems='$AHBOT_MIN_ITEMS', maxitems='$AHBOT_MAX_ITEMS'"
            if [[ $? -ne 0 ]]; then
                notify_telegram "$ERROR_IMPORT_DATABASE"
                rm -rf $MYSQL_CNF
                exit $?
            fi
        fi

        if [[ $APPRECIATION_ENABLED == "true" ]]; then
            if [[ ! -d $ROOT/source/modules/mod-appreciation/data/sql/db-world/base ]]; then
                printf "${COLOR_RED}The appreciation module is enabled but the files aren't where they should be.${COLOR_END}\n"
                printf "${COLOR_RED}Please make sure to install the server first.${COLOR_END}\n"
                notify_telegram "$ERROR_IMPORT_DATABASE"
                exit $?
            fi

            if [[ `ls -1 $ROOT/source/modules/mod-appreciation/data/sql/db-world/base/*.sql 2>/dev/null | wc -l` -gt 0 ]]; then
                for f in $ROOT/source/modules/mod-appreciation/data/sql/db-world/base/*.sql; do
                    FILENAME=$(basename $f)
                    HASH=($(sha1sum $f))

                    if [[ ! -z `mysql --defaults-extra-file=$MYSQL_CNF --skip-column-names $MYSQL_DATABASES_WORLD -e "SELECT * FROM updates WHERE name='$FILENAME' AND hash='${HASH^^}'"` ]]; then
                        printf "${COLOR_ORANGE}Skipping "$(basename $f)"${COLOR_END}\n"
                        continue;
                    fi

                    printf "${COLOR_ORANGE}Importing "$(basename $f)"${COLOR_END}\n"
                    mysql --defaults-extra-file=$MYSQL_CNF $MYSQL_DATABASES_WORLD < $f
                    if [[ $? -ne 0 ]]; then
                        notify_telegram "$ERROR_IMPORT_DATABASE"
                        rm -rf $MYSQL_CNF
                        exit $?
                    fi

                    mysql --defaults-extra-file=$MYSQL_CNF $MYSQL_DATABASES_WORLD -e "DELETE FROM updates WHERE name='$(basename $f)';INSERT INTO updates (name, hash, state) VALUES ('$FILENAME', '${HASH^^}', 'CUSTOM')"
                    if [[ $? -ne 0 ]]; then
                        notify_telegram "$ERROR_IMPORT_DATABASE"
                        rm -rf $MYSQL_CNF
                        exit $?
                    fi
                done
            fi
        fi

        if [[ $ASSISTANT_ENABLED == "true" ]]; then
            if [[ ! -d $ROOT/source/modules/mod-assistant/data/sql/db-world/base ]]; then
                printf "${COLOR_RED}The assistant module is enabled but the files aren't where they should be.${COLOR_END}\n"
                printf "${COLOR_RED}Please make sure to install the server first.${COLOR_END}\n"
                notify_telegram "$ERROR_IMPORT_DATABASE"
                exit $?
            fi

            if [[ `ls -1 $ROOT/source/modules/mod-assistant/data/sql/db-world/base/*.sql 2>/dev/null | wc -l` -gt 0 ]]; then
                for f in $ROOT/source/modules/mod-assistant/data/sql/db-world/base/*.sql; do
                    FILENAME=$(basename $f)
                    HASH=($(sha1sum $f))

                    if [[ ! -z `mysql --defaults-extra-file=$MYSQL_CNF --skip-column-names $MYSQL_DATABASES_WORLD -e "SELECT * FROM updates WHERE name='$FILENAME' AND hash='${HASH^^}'"` ]]; then
                        printf "${COLOR_ORANGE}Skipping "$(basename $f)"${COLOR_END}\n"
                        continue;
                    fi

                    printf "${COLOR_ORANGE}Importing "$(basename $f)"${COLOR_END}\n"
                    mysql --defaults-extra-file=$MYSQL_CNF $MYSQL_DATABASES_WORLD < $f
                    if [[ $? -ne 0 ]]; then
                        notify_telegram "$ERROR_IMPORT_DATABASE"
                        rm -rf $MYSQL_CNF
                        exit $?
                    fi

                    mysql --defaults-extra-file=$MYSQL_CNF $MYSQL_DATABASES_WORLD -e "DELETE FROM updates WHERE name='$(basename $f)';INSERT INTO updates (name, hash, state) VALUES ('$FILENAME', '${HASH^^}', 'CUSTOM')"
                    if [[ $? -ne 0 ]]; then
                        notify_telegram "$ERROR_IMPORT_DATABASE"
                        rm -rf $MYSQL_CNF
                        exit $?
                    fi
                done
            fi
        fi

        if [[ $GROUP_QUESTS_ENABLED == "true" ]]; then
            if [[ ! -d $ROOT/source/modules/mod-groupquests/data/sql/db-world/base ]]; then
                printf "${COLOR_RED}The group quests module is enabled but the files aren't where they should be.${COLOR_END}\n"
                printf "${COLOR_RED}Please make sure to install the server first.${COLOR_END}\n"
                notify_telegram "$ERROR_IMPORT_DATABASE"
                exit $?
            fi

            if [[ `ls -1 $ROOT/source/modules/mod-groupquests/data/sql/db-world/base/*.sql 2>/dev/null | wc -l` -gt 0 ]]; then
                for f in $ROOT/source/modules/mod-groupquests/data/sql/db-world/base/*.sql; do
                    FILENAME=$(basename $f)
                    HASH=($(sha1sum $f))

                    if [[ ! -z `mysql --defaults-extra-file=$MYSQL_CNF --skip-column-names $MYSQL_DATABASES_WORLD -e "SELECT * FROM updates WHERE name='$FILENAME' AND hash='${HASH^^}'"` ]]; then
                        printf "${COLOR_ORANGE}Skipping "$(basename $f)"${COLOR_END}\n"
                        continue;
                    fi

                    printf "${COLOR_ORANGE}Importing "$(basename $f)"${COLOR_END}\n"
                    mysql --defaults-extra-file=$MYSQL_CNF $MYSQL_DATABASES_WORLD < $f
                    if [[ $? -ne 0 ]]; then
                        notify_telegram "$ERROR_IMPORT_DATABASE"
                        rm -rf $MYSQL_CNF
                        exit $?
                    fi

                    mysql --defaults-extra-file=$MYSQL_CNF $MYSQL_DATABASES_WORLD -e "DELETE FROM updates WHERE name='$(basename $f)';INSERT INTO updates (name, hash, state) VALUES ('$FILENAME', '${HASH^^}', 'CUSTOM')"
                    if [[ $? -ne 0 ]]; then
                        notify_telegram "$ERROR_IMPORT_DATABASE"
                        rm -rf $MYSQL_CNF
                        exit $?
                    fi
                done
            fi
        fi

        if [[ $PLAYER_BOTS_ENABLED == "true" ]]; then
            if [[ ! -d $ROOT/source/modules/mod-playerbots/sql/characters ]] || [[ ! -d $ROOT/source/modules/mod-playerbots/sql/world ]]; then
                printf "${COLOR_RED}The playerbots module is enabled but the files aren't where they should be.${COLOR_END}\n"
                printf "${COLOR_RED}Please make sure to install the server first.${COLOR_END}\n"
                notify_telegram $ERROR_IMPORT_DATABASE
                exit $?
            fi

            if [[ `ls -1 $ROOT/source/modules/mod-playerbots/sql/characters/*.sql 2>/dev/null | wc -l` -gt 0 ]]; then
                for f in $ROOT/source/modules/mod-playerbots/sql/characters/*.sql; do
                    FILENAME=$(basename $f)
                    HASH=($(sha1sum $f))

                    if [[ ! -z `mysql --defaults-extra-file=$MYSQL_CNF --skip-column-names $MYSQL_DATABASES_CHARACTERS -e "SELECT * FROM updates WHERE name='$FILENAME' AND hash='${HASH^^}'"` ]]; then
                        printf "${COLOR_ORANGE}Skipping "$(basename $f)"${COLOR_END}\n"
                        continue;
                    fi

                    printf "${COLOR_ORANGE}Importing "$(basename $f)"${COLOR_END}\n"
                    mysql --defaults-extra-file=$MYSQL_CNF $MYSQL_DATABASES_CHARACTERS < $f
                    if [[ $? -ne 0 ]]; then
                        notify_telegram $ERROR_IMPORT_DATABASE
                        rm -rf $MYSQL_CNF
                        exit $?
                    fi

                    mysql --defaults-extra-file=$MYSQL_CNF $MYSQL_DATABASES_CHARACTERS -e "DELETE FROM updates WHERE name='$(basename $f)';INSERT INTO updates (name, hash, state) VALUES ('$FILENAME', '${HASH^^}', 'CUSTOM')"
                    if [[ $? -ne 0 ]]; then
                        notify_telegram $ERROR_IMPORT_DATABASE
                        rm -rf $MYSQL_CNF
                        exit $?
                    fi
                done
            fi

            if [[ `ls -1 $ROOT/source/modules/mod-playerbots/sql/playerbots/base/*.sql 2>/dev/null | wc -l` -gt 0 ]]; then
                for f in $ROOT/source/modules/mod-playerbots/sql/playerbots/base/*.sql; do
                    if [[ ! -z `mysql --defaults-extra-file=$MYSQL_CNF --skip-column-names $PLAYER_BOTS_DATABASE -e "SHOW TABLES LIKE '$(basename $f .sql)'"` ]]; then
                        printf "${COLOR_ORANGE}Skipping "$(basename $f)"${COLOR_END}\n"
                        continue;
                    fi

                    printf "${COLOR_ORANGE}Importing "$(basename $f)"${COLOR_END}\n"
                    mysql --defaults-extra-file=$MYSQL_CNF $PLAYER_BOTS_DATABASE < $f
                    if [[ $? -ne 0 ]]; then
                        notify_telegram $ERROR_IMPORT_DATABASE
                        rm -rf $MYSQL_CNF
                        exit $?
                    fi
                done
            fi

            if [[ `ls -1 $ROOT/source/modules/mod-playerbots/sql/world/*.sql 2>/dev/null | wc -l` -gt 0 ]]; then
                for f in $ROOT/source/modules/mod-playerbots/sql/world/*.sql; do
                    FILENAME=$(basename $f)
                    HASH=($(sha1sum $f))

                    if [[ ! -z `mysql --defaults-extra-file=$MYSQL_CNF --skip-column-names $MYSQL_DATABASES_WORLD -e "SELECT * FROM updates WHERE name='$FILENAME' AND hash='${HASH^^}'"` ]]; then
                        printf "${COLOR_ORANGE}Skipping "$(basename $f)"${COLOR_END}\n"
                        continue;
                    fi

                    printf "${COLOR_ORANGE}Importing "$(basename $f)"${COLOR_END}\n"
                    mysql --defaults-extra-file=$MYSQL_CNF $MYSQL_DATABASES_WORLD < $f
                    if [[ $? -ne 0 ]]; then
                        notify_telegram $ERROR_IMPORT_DATABASE
                        rm -rf $MYSQL_CNF
                        exit $?
                    fi

                    mysql --defaults-extra-file=$MYSQL_CNF $MYSQL_DATABASES_WORLD -e "DELETE FROM updates WHERE name='$(basename $f)';INSERT INTO updates (name, hash, state) VALUES ('$FILENAME', '${HASH^^}', 'CUSTOM')"
                    if [[ $? -ne 0 ]]; then
                        notify_telegram $ERROR_IMPORT_DATABASE
                        rm -rf $MYSQL_CNF
                        exit $?
                    fi
                done
            fi
        fi

        if [[ $RECRUIT_A_FRIEND_ENABLED == "true" ]]; then
            if [[ ! -d $ROOT/source/modules/mod-recruitafriend/data/sql/db-auth/base ]]; then
                printf "${COLOR_RED}The recruit-a-friend module is enabled but the files aren't where they should be.${COLOR_END}\n"
                printf "${COLOR_RED}Please make sure to install the server first.${COLOR_END}\n"
                notify_telegram "$ERROR_IMPORT_DATABASE"
                exit $?
            fi

            if [[ `ls -1 $ROOT/source/modules/mod-recruitafriend/data/sql/db-auth/base/*.sql 2>/dev/null | wc -l` -gt 0 ]]; then
                for f in $ROOT/source/modules/mod-recruitafriend/data/sql/db-auth/base/*.sql; do
                    FILENAME=$(basename $f)
                    HASH=($(sha1sum $f))

                    if [[ ! -z `mysql --defaults-extra-file=$MYSQL_CNF --skip-column-names $MYSQL_DATABASES_AUTH -e "SELECT * FROM updates WHERE name='$FILENAME' AND hash='${HASH^^}'"` ]]; then
                        printf "${COLOR_ORANGE}Skipping "$(basename $f)"${COLOR_END}\n"
                        continue;
                    fi

                    printf "${COLOR_ORANGE}Importing "$(basename $f)"${COLOR_END}\n"
                    mysql --defaults-extra-file=$MYSQL_CNF $MYSQL_DATABASES_AUTH < $f
                    if [[ $? -ne 0 ]]; then
                        notify_telegram "$ERROR_IMPORT_DATABASE"
                        rm -rf $MYSQL_CNF
                        exit $?
                    fi

                    mysql --defaults-extra-file=$MYSQL_CNF $MYSQL_DATABASES_AUTH -e "DELETE FROM updates WHERE name='$(basename $f)';INSERT INTO updates (name, hash, state) VALUES ('$FILENAME', '${HASH^^}', 'CUSTOM')"
                    if [[ $? -ne 0 ]]; then
                        notify_telegram "$ERROR_IMPORT_DATABASE"
                        rm -rf $MYSQL_CNF
                        exit $?
                    fi
                done
            fi
        fi

        if [[ `ls -1 $ROOT/sql/characters/*.sql 2>/dev/null | wc -l` -gt 0 ]]; then
            for f in $ROOT/sql/characters/*.sql; do
                printf "${COLOR_ORANGE}Importing "$(basename $f)"${COLOR_END}\n"
                mysql --defaults-extra-file=$MYSQL_CNF $MYSQL_DATABASES_CHARACTERS < $f
                if [[ $? -ne 0 ]]; then
                    notify_telegram "$ERROR_IMPORT_DATABASE"
                    rm -rf $MYSQL_CNF
                    exit $?
                fi
            done
        fi

        if [[ `ls -1 $ROOT/sql/world/*.sql 2>/dev/null | wc -l` -gt 0 ]]; then
            for f in $ROOT/sql/world/*.sql; do
                printf "${COLOR_ORANGE}Importing "$(basename $f)"${COLOR_END}\n"
                mysql --defaults-extra-file=$MYSQL_CNF $MYSQL_DATABASES_WORLD < $f
                if [[ $? -ne 0 ]]; then
                    notify_telegram "$ERROR_IMPORT_DATABASE"
                    rm -rf $MYSQL_CNF
                    exit $?
                fi
            done
        fi

        printf "${COLOR_ORANGE}Adding to the realmlist (id: $WORLD_ID, name: $WORLD_NAME, address $WORLD_ADDRESS, port $WORLD_PORT)${COLOR_END}\n"
        mysql --defaults-extra-file=$MYSQL_CNF $MYSQL_DATABASES_AUTH -e "DELETE FROM realmlist WHERE id='$WORLD_ID';INSERT INTO realmlist (id, name, address, localAddress, localSubnetMask, port) VALUES ('$WORLD_ID', '$WORLD_NAME', '$WORLD_ADDRESS', '$WORLD_ADDRESS', '255.255.255.0', '$WORLD_PORT')"
        if [[ $? -ne 0 ]]; then
            notify_telegram "$ERROR_IMPORT_DATABASE"
            rm -rf $MYSQL_CNF
            exit $?
        fi

        printf "${COLOR_ORANGE}Updating message of the day${COLOR_END}\n"
        mysql --defaults-extra-file=$MYSQL_CNF $MYSQL_DATABASES_AUTH -e "DELETE FROM motd WHERE realmid='$WORLD_ID';INSERT INTO motd (realmid, text) VALUES ('$WORLD_ID', '$WORLD_MOTD')"
        if [[ $? -ne 0 ]]; then
            notify_telegram "$ERROR_IMPORT_DATABASE"
            rm -rf $MYSQL_CNF
            exit $?
        fi
    fi

    rm -rf $MYSQL_CNF

    printf "${COLOR_GREEN}Finished importing the database files...${COLOR_END}\n"
}

function copy_dbc_files
{
    printf "${COLOR_GREEN}Copying modified client data files...${COLOR_END}\n"

    if [[ $1 == "world" ]] || [[ $1 == "both" ]]; then
        if [[ ! -d $ROOT/dbc ]]; then
            mkdir $ROOT/dbc
        fi

        if [[ `ls -1 $ROOT/dbc/*.dbc 2>/dev/null | wc -l` -gt 0 ]]; then
            for f in $ROOT/dbc/*.dbc; do
                printf "${COLOR_ORANGE}Copying "$(basename $f)"${COLOR_END}\n"
                cp $f $ROOT/source/bin/dbc/$(basename $f)
                if [[ $? -ne 0 ]]; then
                    notify_telegram "$ERROR_COPY_CUSTOM_DBC"
                    exit $?
                fi
            done
        else
            printf "${COLOR_ORANGE}No files found in the directory${COLOR_END}\n"
        fi
    else
        printf "${COLOR_ORANGE}Skipping process due to world server being disabled${COLOR_END}\n"
    fi

    printf "${COLOR_GREEN}Finished copying modified client data files...${COLOR_END}\n"
}

function set_config
{
    printf "${COLOR_GREEN}Updating the config files...${COLOR_END}\n"

    if [[ $1 == "both" ]] || [[ $1 == "auth" ]]; then
        if [[ ! -f $ROOT/source/etc/authserver.conf.dist ]]; then
            printf "${COLOR_RED}The config file authserver.conf.dist is missing.${COLOR_END}\n"
            printf "${COLOR_RED}Please make sure to install the server first.${COLOR_END}\n"
            notify_telegram "$ERROR_UPDATE_CONFIG"
            exit $?
        fi

        printf "${COLOR_ORANGE}Updating authserver.conf${COLOR_END}\n"

        cp $ROOT/source/etc/authserver.conf.dist $ROOT/source/etc/authserver.conf

        sed -i 's/LoginDatabaseInfo =.*/LoginDatabaseInfo = "'$MYSQL_HOSTNAME';'$MYSQL_PORT';'$MYSQL_USERNAME';'$MYSQL_PASSWORD';'$MYSQL_DATABASES_AUTH'"/g' $ROOT/source/etc/authserver.conf
        sed -i 's/Updates.EnableDatabases =.*/Updates.EnableDatabases = 0/g' $ROOT/source/etc/authserver.conf
    fi

    if [[ $1 == "both" ]] || [[ $1 == "world" ]]; then
        if [[ ! -f $ROOT/source/etc/worldserver.conf.dist ]]; then
            printf "${COLOR_RED}The config file worldserver.conf.dist is missing.${COLOR_END}\n"
            printf "${COLOR_RED}Please make sure to install the server first.${COLOR_END}\n"
            notify_telegram "$ERROR_UPDATE_CONFIG"
            exit $?
        fi

        printf "${COLOR_ORANGE}Updating worldserver.conf${COLOR_END}\n"

        cp $ROOT/source/etc/worldserver.conf.dist $ROOT/source/etc/worldserver.conf

        sed -i 's/LoginDatabaseInfo     =.*/LoginDatabaseInfo     = "'$MYSQL_HOSTNAME';'$MYSQL_PORT';'$MYSQL_USERNAME';'$MYSQL_PASSWORD';'$MYSQL_DATABASES_AUTH'"/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/WorldDatabaseInfo     =.*/WorldDatabaseInfo     = "'$MYSQL_HOSTNAME';'$MYSQL_PORT';'$MYSQL_USERNAME';'$MYSQL_PASSWORD';'$MYSQL_DATABASES_WORLD'"/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/CharacterDatabaseInfo =.*/CharacterDatabaseInfo = "'$MYSQL_HOSTNAME';'$MYSQL_PORT';'$MYSQL_USERNAME';'$MYSQL_PASSWORD';'$MYSQL_DATABASES_CHARACTERS'"/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/Updates.EnableDatabases =.*/Updates.EnableDatabases = 0/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/RealmID =.*/RealmID = '$WORLD_ID'/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/WorldServerPort =.*/WorldServerPort = '$WORLD_PORT'/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/GameType =.*/GameType = 1/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/RealmZone =.*/RealmZone = 2/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/Expansion =.*/Expansion = 2/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/PlayerLimit =.*/PlayerLimit = 1000/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/StrictPlayerNames =.*/StrictPlayerNames = 3/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/StrictCharterNames =.*/StrictCharterNames = 3/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/StrictPetNames =.*/StrictPetNames = 3/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/AllowPlayerCommands =.*/AllowPlayerCommands = 1/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/Quests.IgnoreRaid =.*/Quests.IgnoreRaid = 1/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/Warden.Enabled =.*/Warden.Enabled = 0/g' $ROOT/source/etc/worldserver.conf
        if [[ $PRELOAD_MAP_GRIDS == "true" ]]; then
            sed -i 's/PreloadAllNonInstancedMapGrids =.*/PreloadAllNonInstancedMapGrids = 1/g' $ROOT/source/etc/worldserver.conf

            if [[ $SET_CREATURES_ACTIVE == "true" ]]; then
                sed -i 's/SetAllCreaturesWithWaypointMovementActive =.*/SetAllCreaturesWithWaypointMovementActive = 1/g' $ROOT/source/etc/worldserver.conf
            else
                sed -i 's/SetAllCreaturesWithWaypointMovementActive =.*/SetAllCreaturesWithWaypointMovementActive = 0/g' $ROOT/source/etc/worldserver.conf
            fi
        else
            sed -i 's/PreloadAllNonInstancedMapGrids =.*/PreloadAllNonInstancedMapGrids = 0/g' $ROOT/source/etc/worldserver.conf
            sed -i 's/SetAllCreaturesWithWaypointMovementActive =.*/SetAllCreaturesWithWaypointMovementActive = 0/g' $ROOT/source/etc/worldserver.conf
        fi
        sed -i 's/Minigob.Manabonk.Enable =.*/Minigob.Manabonk.Enable = 0/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/Rate.XP.Kill      =.*/Rate.XP.Kill      = 1/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/Rate.XP.Quest     =.*/Rate.XP.Quest     = 1/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/Rate.XP.Quest.DF  =.*/Rate.XP.Quest.DF  = 1/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/Rate.XP.Explore   =.*/Rate.XP.Explore   = 1/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/Rate.XP.Pet       =.*/Rate.XP.Pet       = 1/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/Rate.Rest.InGame                 =.*/Rate.Rest.InGame                 = 1/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/Rate.Rest.Offline.InTavernOrCity =.*/Rate.Rest.Offline.InTavernOrCity = 1/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/Rate.Rest.Offline.InWilderness   =.*/Rate.Rest.Offline.InWilderness   = 1/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/GM.LoginState =.*/GM.LoginState = 1/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/GM.Visible =.*/GM.Visible = 0/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/GM.Chat =.*/GM.Chat = 1/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/GM.WhisperingTo =.*/GM.WhisperingTo = 0/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/GM.InGMList.Level =.*/GM.InGMList.Level = 1/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/GM.InWhoList.Level =.*/GM.InWhoList.Level = 0/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/GM.StartLevel = .*/GM.StartLevel = 1/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/GM.AllowInvite =.*/GM.AllowInvite = 0/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/GM.AllowFriend =.*/GM.AllowFriend = 0/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/GM.LowerSecurity =.*/GM.LowerSecurity = 0/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/LeaveGroupOnLogout.Enabled =.*/LeaveGroupOnLogout.Enabled = 0/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/Group.Raid.LevelRestriction =.*/Group.Raid.LevelRestriction = 1/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/Progression.Patch =.*/Progression.Patch = '$PROGRESSION_ACTIVE_PATCH'/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/Progression.IcecrownCitadel.Aura =.*/Progression.IcecrownCitadel.Aura = '$PROGRESSION_ICECROWN_CITADEL_AURA'/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/Progression.QuestInfo.Enforced =.*/Progression.QuestInfo.Enforced = 0/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/Progression.DungeonFinder.Enforced =.*/Progression.DungeonFinder.Enforced = 1/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/DBC.EnforceItemAttributes =.*/DBC.EnforceItemAttributes = 0/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/MapUpdate.Threads =.*/MapUpdate.Threads = '$(nproc)'/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/MinWorldUpdateTime =.*/MinWorldUpdateTime = 10/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/MapUpdateInterval =.*/MapUpdateInterval = 100/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/NpcBot.MaxBots =.*/NpcBot.MaxBots = 39/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/NpcBot.Botgiver.FilterRaces =.*/NpcBot.Botgiver.FilterRaces = 1/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/NpcBot.TankTargetIconMask =.*/NpcBot.TankTargetIconMask = 128/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/NpcBot.OffTankTargetIconMask =.*/NpcBot.OffTankTargetIconMask = 64/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/NpcBot.Enable.Raid          =.*/NpcBot.Enable.Raid          = 1/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/NpcBot.Enable.BG            =.*/NpcBot.Enable.BG            = 1/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/NpcBot.Enable.Arena         =.*/NpcBot.Enable.Arena         = 1/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/NpcBot.Cost =.*/NpcBot.Cost = 0/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/NpcBot.EngageDelay.DPS  =.*/NpcBot.EngageDelay.DPS  = 8000/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/NpcBot.EngageDelay.Heal =.*/NpcBot.EngageDelay.Heal = 1000/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/NpcBot.Classes.ObsidianDestroyer.Enable =.*/NpcBot.Classes.ObsidianDestroyer.Enable = 0/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/NpcBot.Classes.Archmage.Enable          =.*/NpcBot.Classes.Archmage.Enable          = 0/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/NpcBot.Classes.Dreadlord.Enable         =.*/NpcBot.Classes.Dreadlord.Enable         = 0/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/NpcBot.Classes.SpellBreaker.Enable      =.*/NpcBot.Classes.SpellBreaker.Enable      = 0/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/NpcBot.Classes.DarkRanger.Enable        =.*/NpcBot.Classes.DarkRanger.Enable        = 0/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/NpcBot.Classes.Necromancer.Enable       =.*/NpcBot.Classes.Necromancer.Enable       = 0/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/NpcBot.Classes.SeaWitch.Enable          =.*/NpcBot.Classes.SeaWitch.Enable          = 0/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/NpcBot.Classes.CryptLord.Enable         =.*/NpcBot.Classes.CryptLord.Enable         = 0/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/NpcBot.EnrageOnDismiss =.*/NpcBot.EnrageOnDismiss = 0/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/NpcBot.WanderingBots.BG.Enable =.*/NpcBot.WanderingBots.BG.Enable = 1/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/NpcBot.WanderingBots.BG.TargetTeamPlayersCount.AV =.*/NpcBot.WanderingBots.BG.TargetTeamPlayersCount.AV = 39/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/NpcBot.WanderingBots.BG.TargetTeamPlayersCount.WS =.*/NpcBot.WanderingBots.BG.TargetTeamPlayersCount.WS = 9/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/NpcBot.WanderingBots.BG.TargetTeamPlayersCount.AB =.*/NpcBot.WanderingBots.BG.TargetTeamPlayersCount.AB = 14/g' $ROOT/source/etc/worldserver.conf
        sed -i 's/NpcBot.WanderingBots.BG.CapLevel =.*/NpcBot.WanderingBots.BG.CapLevel = 1/g' $ROOT/source/etc/worldserver.conf

        if [[ $ACCOUNT_BOUND_ENABLED == "true" ]]; then
            if [[ ! -f $ROOT/source/etc/modules/mod_accountbound.conf.dist ]]; then
                printf "${COLOR_RED}The config file mod_accountbound.conf.dist is missing.${COLOR_END}\n"
                printf "${COLOR_RED}Please make sure to install the server first.${COLOR_END}\n"
                notify_telegram "$ERROR_UPDATE_CONFIG"
                exit $?
            fi

            printf "${COLOR_ORANGE}Updating mod_accountbound.conf${COLOR_END}\n"

            cp $ROOT/source/etc/modules/mod_accountbound.conf.dist $ROOT/source/etc/modules/mod_accountbound.conf

            sed -i 's/AccountBound.Heirlooms =.*/AccountBound.Heirlooms = 1/g' $ROOT/source/etc/modules/mod_accountbound.conf
        else
            if [[ -f $ROOT/source/etc/modules/mod_accountbound.conf.dist ]]; then
                rm -rf $ROOT/source/etc/modules/mod_accountbound.conf.dist
            fi

            if [[ -f $ROOT/source/etc/modules/mod_accountbound.conf ]]; then
                rm -rf $ROOT/source/etc/modules/mod_accountbound.conf
            fi
        fi

        if [[ $AHBOT_ENABLED == "true" ]]; then
            if [[ ! -f $ROOT/source/etc/modules/mod_ahbot.conf.dist ]]; then
                printf "${COLOR_RED}The config file mod_ahbot.conf.dist is missing.${COLOR_END}\n"
                printf "${COLOR_RED}Please make sure to install the server first.${COLOR_END}\n"
                notify_telegram "$ERROR_UPDATE_CONFIG"
                exit $?
            fi

            printf "${COLOR_ORANGE}Updating mod_ahbot.conf${COLOR_END}\n"

            cp $ROOT/source/etc/modules/mod_ahbot.conf.dist $ROOT/source/etc/modules/mod_ahbot.conf

            sed -i 's/AuctionHouseBot.EnableBuyer =.*/AuctionHouseBot.EnableBuyer = 1/g' $ROOT/source/etc/modules/mod_ahbot.conf
            sed -i 's/AuctionHouseBot.EnableSeller =.*/AuctionHouseBot.EnableSeller = 1/g' $ROOT/source/etc/modules/mod_ahbot.conf
            sed -i 's/AuctionHouseBot.UseBuyPriceForBuyer =.*/AuctionHouseBot.UseBuyPriceForBuyer = 1/g' $ROOT/source/etc/modules/mod_ahbot.conf
            sed -i 's/AuctionHouseBot.Account =.*/AuctionHouseBot.Account = 1/g' $ROOT/source/etc/modules/mod_ahbot.conf
            sed -i 's/AuctionHouseBot.GUID =.*/AuctionHouseBot.GUID = 1/g' $ROOT/source/etc/modules/mod_ahbot.conf
            sed -i 's/AuctionHouseBot.DisableItemsAboveLevel =.*/AuctionHouseBot.DisableItemsAboveLevel = '$AHBOT_MAX_ITEM_LEVEL'/g' $ROOT/source/etc/modules/mod_ahbot.conf
        else
            if [[ -f $ROOT/source/etc/modules/mod_ahbot.conf.dist ]]; then
                rm -rf $ROOT/source/etc/modules/mod_ahbot.conf.dist
            fi

            if [[ -f $ROOT/source/etc/modules/mod_ahbot.conf ]]; then
                rm -rf $ROOT/source/etc/modules/mod_ahbot.conf
            fi
        fi

        if [[ $APPRECIATION_ENABLED == "true" ]]; then
            if [[ ! -f $ROOT/source/etc/modules/mod_appreciation.conf.dist ]]; then
                printf "${COLOR_RED}The config file mod_appreciation.conf.dist is missing.${COLOR_END}\n"
                printf "${COLOR_RED}Please make sure to install the server first.${COLOR_END}\n"
                notify_telegram "$ERROR_UPDATE_CONFIG"
                exit $?
            fi

            printf "${COLOR_ORANGE}Updating mod_appreciation.conf${COLOR_END}\n"

            cp $ROOT/source/etc/modules/mod_appreciation.conf.dist $ROOT/source/etc/modules/mod_appreciation.conf

            if [[ $PROGRESSION_ACTIVE_PATCH -lt 12 ]]; then
                sed -i 's/Appreciation.LevelBoost.TargetLevel =.*/Appreciation.LevelBoost.TargetLevel = 60/g' $ROOT/source/etc/modules/mod_appreciation.conf
                sed -i 's/Appreciation.LevelBoost.IncludedCopper =.*/Appreciation.LevelBoost.IncludedCopper = 2500000/g' $ROOT/source/etc/modules/mod_appreciation.conf
            elif [[ $PROGRESSION_ACTIVE_PATCH -lt 17 ]]; then
                sed -i 's/Appreciation.LevelBoost.TargetLevel =.*/Appreciation.LevelBoost.TargetLevel = 70/g' $ROOT/source/etc/modules/mod_appreciation.conf
                sed -i 's/Appreciation.LevelBoost.IncludedCopper =.*/Appreciation.LevelBoost.IncludedCopper = 5000000/g' $ROOT/source/etc/modules/mod_appreciation.conf
            else
                sed -i 's/Appreciation.RewardAtMaxLevel.Enabled =.*/Appreciation.RewardAtMaxLevel.Enabled = 1/g' $ROOT/source/etc/modules/mod_appreciation.conf
                sed -i 's/Appreciation.LevelBoost.IncludedCopper =.*/Appreciation.LevelBoost.IncludedCopper = 10000000/g' $ROOT/source/etc/modules/mod_appreciation.conf
            fi
            sed -i 's/Appreciation.RewardAtMaxLevel.Enabled =.*/Appreciation.RewardAtMaxLevel.Enabled = 1/g' $ROOT/source/etc/modules/mod_appreciation.conf
        else
            if [[ -f $ROOT/source/etc/modules/mod_appreciation.conf.dist ]]; then
                rm -rf $ROOT/source/etc/modules/mod_appreciation.conf.dist
            fi

            if [[ -f $ROOT/source/etc/modules/mod_appreciation.conf ]]; then
                rm -rf $ROOT/source/etc/modules/mod_appreciation.conf
            fi
        fi

        if [[ $ASSISTANT_ENABLED == "true" ]]; then
            if [[ ! -f $ROOT/source/etc/modules/mod_assistant.conf.dist ]]; then
                printf "${COLOR_RED}The config file mod_assistant.conf.dist is missing.${COLOR_END}\n"
                printf "${COLOR_RED}Please make sure to install the server first.${COLOR_END}\n"
                notify_telegram "$ERROR_UPDATE_CONFIG"
                exit $?
            fi

            printf "${COLOR_ORANGE}Updating mod_assistant.conf${COLOR_END}\n"

            cp $ROOT/source/etc/modules/mod_assistant.conf.dist $ROOT/source/etc/modules/mod_assistant.conf

            if [[ $PROGRESSION_ACTIVE_PATCH -lt 17 ]]; then
                sed -i 's/Assistant.Heirlooms.Enabled  =.*/Assistant.Heirlooms.Enabled  = 0/g' $ROOT/source/etc/modules/mod_assistant.conf
                sed -i 's/Assistant.Glyphs.Enabled     =.*/Assistant.Glyphs.Enabled     = 0/g' $ROOT/source/etc/modules/mod_assistant.conf
                sed -i 's/Assistant.Gems.Enabled       =.*/Assistant.Gems.Enabled       = 0/g' $ROOT/source/etc/modules/mod_assistant.conf
            else
                sed -i 's/Assistant.Heirlooms.Enabled  =.*/Assistant.Heirlooms.Enabled  = 1/g' $ROOT/source/etc/modules/mod_assistant.conf
                sed -i 's/Assistant.Glyphs.Enabled     =.*/Assistant.Glyphs.Enabled     = 1/g' $ROOT/source/etc/modules/mod_assistant.conf
                sed -i 's/Assistant.Gems.Enabled       =.*/Assistant.Gems.Enabled       = 1/g' $ROOT/source/etc/modules/mod_assistant.conf
            fi
            sed -i 's/Assistant.Containers.Enabled =.*/Assistant.Containers.Enabled = 1/g' $ROOT/source/etc/modules/mod_assistant.conf
            sed -i 's/Assistant.Utilities.Enabled            =.*/Assistant.Utilities.Enabled            = 1/g' $ROOT/source/etc/modules/mod_assistant.conf
            sed -i 's/Assistant.Utilities.NameChange.Cost    =.*/Assistant.Utilities.NameChange.Cost    = 100000/g' $ROOT/source/etc/modules/mod_assistant.conf
            sed -i 's/Assistant.Utilities.Customize.Cost     =.*/Assistant.Utilities.Customize.Cost     = 500000/g' $ROOT/source/etc/modules/mod_assistant.conf
            sed -i 's/Assistant.Utilities.RaceChange.Cost    =.*/Assistant.Utilities.RaceChange.Cost    = 5000000/g' $ROOT/source/etc/modules/mod_assistant.conf
            sed -i 's/Assistant.Utilities.FactionChange.Cost =.*/Assistant.Utilities.FactionChange.Cost = 10000000/g' $ROOT/source/etc/modules/mod_assistant.conf
            sed -i 's/Assistant.FlightPaths.Vanilla.Enabled                  =.*/Assistant.FlightPaths.Vanilla.Enabled                  = 1/g' $ROOT/source/etc/modules/mod_assistant.conf
            sed -i 's/Assistant.FlightPaths.Vanilla.RequiredLevel            =.*/Assistant.FlightPaths.Vanilla.RequiredLevel            = 60/g' $ROOT/source/etc/modules/mod_assistant.conf
            sed -i 's/Assistant.FlightPaths.Vanilla.Cost                     =.*/Assistant.FlightPaths.Vanilla.Cost                     = 250000/g' $ROOT/source/etc/modules/mod_assistant.conf
            if [[ $PROGRESSION_ACTIVE_PATCH -lt 12 ]]; then
                sed -i 's/Assistant.FlightPaths.BurningCrusade.Enabled           =.*/Assistant.FlightPaths.BurningCrusade.Enabled           = 0/g' $ROOT/source/etc/modules/mod_assistant.conf
            else
                sed -i 's/Assistant.FlightPaths.BurningCrusade.Enabled           =.*/Assistant.FlightPaths.BurningCrusade.Enabled           = 1/g' $ROOT/source/etc/modules/mod_assistant.conf
            fi
            sed -i 's/Assistant.FlightPaths.BurningCrusade.RequiredLevel     =.*/Assistant.FlightPaths.BurningCrusade.RequiredLevel     = 70/g' $ROOT/source/etc/modules/mod_assistant.conf
            sed -i 's/Assistant.FlightPaths.BurningCrusade.Cost              =.*/Assistant.FlightPaths.BurningCrusade.Cost              = 1000000/g' $ROOT/source/etc/modules/mod_assistant.conf
            if [[ $PROGRESSION_ACTIVE_PATCH -lt 17 ]]; then
                sed -i 's/Assistant.FlightPaths.WrathOfTheLichKing.Enabled       =.*/Assistant.FlightPaths.WrathOfTheLichKing.Enabled       = 0/g' $ROOT/source/etc/modules/mod_assistant.conf
            else
                sed -i 's/Assistant.FlightPaths.WrathOfTheLichKing.Enabled       =.*/Assistant.FlightPaths.WrathOfTheLichKing.Enabled       = 1/g' $ROOT/source/etc/modules/mod_assistant.conf
            fi
            sed -i 's/Assistant.FlightPaths.WrathOfTheLichKing.RequiredLevel =.*/Assistant.FlightPaths.WrathOfTheLichKing.RequiredLevel = 80/g' $ROOT/source/etc/modules/mod_assistant.conf
            sed -i 's/Assistant.FlightPaths.WrathOfTheLichKing.Cost          =.*/Assistant.FlightPaths.WrathOfTheLichKing.Cost          = 2500000/g' $ROOT/source/etc/modules/mod_assistant.conf
            sed -i 's/Assistant.Professions.Apprentice.Enabled  =.*/Assistant.Professions.Apprentice.Enabled  = 1/g' $ROOT/source/etc/modules/mod_assistant.conf
            sed -i 's/Assistant.Professions.Apprentice.Cost     =.*/Assistant.Professions.Apprentice.Cost     = 1000000/g' $ROOT/source/etc/modules/mod_assistant.conf
            sed -i 's/Assistant.Professions.Journeyman.Enabled  =.*/Assistant.Professions.Journeyman.Enabled  = 1/g' $ROOT/source/etc/modules/mod_assistant.conf
            sed -i 's/Assistant.Professions.Journeyman.Cost     =.*/Assistant.Professions.Journeyman.Cost     = 2500000/g' $ROOT/source/etc/modules/mod_assistant.conf
            sed -i 's/Assistant.Professions.Expert.Enabled      =.*/Assistant.Professions.Expert.Enabled      = 1/g' $ROOT/source/etc/modules/mod_assistant.conf
            sed -i 's/Assistant.Professions.Expert.Cost         =.*/Assistant.Professions.Expert.Cost         = 5000000/g' $ROOT/source/etc/modules/mod_assistant.conf
            sed -i 's/Assistant.Professions.Artisan.Enabled     =.*/Assistant.Professions.Artisan.Enabled     = 1/g' $ROOT/source/etc/modules/mod_assistant.conf
            sed -i 's/Assistant.Professions.Artisan.Cost        =.*/Assistant.Professions.Artisan.Cost        = 7500000/g' $ROOT/source/etc/modules/mod_assistant.conf
            sed -i 's/Assistant.Professions.Master.Enabled      =.*/Assistant.Professions.Master.Enabled      = 1/g' $ROOT/source/etc/modules/mod_assistant.conf
            sed -i 's/Assistant.Professions.Master.Cost         =.*/Assistant.Professions.Master.Cost         = 12500000/g' $ROOT/source/etc/modules/mod_assistant.conf
            sed -i 's/Assistant.Professions.GrandMaster.Enabled =.*/Assistant.Professions.GrandMaster.Enabled = 1/g' $ROOT/source/etc/modules/mod_assistant.conf
            sed -i 's/Assistant.Professions.GrandMaster.Cost    =.*/Assistant.Professions.GrandMaster.Cost    = 25000000/g' $ROOT/source/etc/modules/mod_assistant.conf
        else
            if [[ -f $ROOT/source/etc/modules/mod_assistant.conf.dist ]]; then
                rm -rf $ROOT/source/etc/modules/mod_assistant.conf.dist
            fi

            if [[ -f $ROOT/source/etc/modules/mod_assistant.conf ]]; then
                rm -rf $ROOT/source/etc/modules/mod_assistant.conf
            fi
        fi

        if [[ $GUILD_FUNDS_ENABLED == "true" ]]; then
            if [[ ! -f $ROOT/source/etc/modules/mod_guildfunds.conf.dist ]]; then
                printf "${COLOR_RED}The config file mod_guildfunds.conf.dist is missing.${COLOR_END}\n"
                printf "${COLOR_RED}Please make sure to install the server first.${COLOR_END}\n"
                notify_telegram "$ERROR_UPDATE_CONFIG"
                exit $?
            fi

            printf "${COLOR_ORANGE}Updating mod_guildfunds.conf${COLOR_END}\n"

            cp $ROOT/source/etc/modules/mod_guildfunds.conf.dist $ROOT/source/etc/modules/mod_guildfunds.conf

            sed -i 's/GuildFunds.Looted =.*/GuildFunds.Looted = 10/g' $ROOT/source/etc/modules/mod_guildfunds.conf
            sed -i 's/GuildFunds.Quests =.*/GuildFunds.Quests = 3/g' $ROOT/source/etc/modules/mod_guildfunds.conf
        else
            if [[ -f $ROOT/source/etc/modules/mod_guildfunds.conf.dist ]]; then
                rm -rf $ROOT/source/etc/modules/mod_guildfunds.conf.dist
            fi

            if [[ -f $ROOT/source/etc/modules/mod_guildfunds.conf ]]; then
                rm -rf $ROOT/source/etc/modules/mod_guildfunds.conf
            fi
        fi

        if [[ $LEARN_SPELLS_ENABLED == "true" ]]; then
            if [[ ! -f $ROOT/source/etc/modules/mod_learnspells.conf.dist ]]; then
                printf "${COLOR_RED}The config file mod_learnspells.conf.dist is missing.${COLOR_END}\n"
                printf "${COLOR_RED}Please make sure to install the server first.${COLOR_END}\n"
                notify_telegram "$ERROR_UPDATE_CONFIG"
                exit $?
            fi

            printf "${COLOR_ORANGE}Updating mod_learnspells.conf${COLOR_END}\n"

            cp $ROOT/source/etc/modules/mod_learnspells.conf.dist $ROOT/source/etc/modules/mod_learnspells.conf

            sed -i 's/LearnSpells.ClassSpells =.*/LearnSpells.ClassSpells = 1/g' $ROOT/source/etc/modules/mod_learnspells.conf
            sed -i 's/LearnSpells.TalentRanks =.*/LearnSpells.TalentRanks = 1/g' $ROOT/source/etc/modules/mod_learnspells.conf
            sed -i 's/LearnSpells.Proficiencies =.*/LearnSpells.Proficiencies = 1/g' $ROOT/source/etc/modules/mod_learnspells.conf
            sed -i 's/LearnSpells.SpellsFromQuests =.*/LearnSpells.SpellsFromQuests = 1/g' $ROOT/source/etc/modules/mod_learnspells.conf
            if [[ $PROGRESSION_ACTIVE_PATCH -lt 12 ]]; then
                sed -i 's/LearnSpells.Riding.Apprentice =.*/LearnSpells.Riding.Apprentice = 0/g' $ROOT/source/etc/modules/mod_learnspells.conf
                sed -i 's/LearnSpells.Riding.Journeyman =.*/LearnSpells.Riding.Journeyman = 0/g' $ROOT/source/etc/modules/mod_learnspells.conf
            else
                sed -i 's/LearnSpells.Riding.Apprentice =.*/LearnSpells.Riding.Apprentice = 1/g' $ROOT/source/etc/modules/mod_learnspells.conf
                sed -i 's/LearnSpells.Riding.Journeyman =.*/LearnSpells.Riding.Journeyman = 1/g' $ROOT/source/etc/modules/mod_learnspells.conf
            fi
            if [[ $PROGRESSION_ACTIVE_PATCH -lt 17 ]]; then
                sed -i 's/LearnSpells.Riding.Expert =.*/LearnSpells.Riding.Expert = 0/g' $ROOT/source/etc/modules/mod_learnspells.conf
            else
                sed -i 's/LearnSpells.Riding.Expert =.*/LearnSpells.Riding.Expert = 1/g' $ROOT/source/etc/modules/mod_learnspells.conf
            fi
            sed -i 's/LearnSpells.Riding.Artisan =.*/LearnSpells.Riding.Artisan = 0/g' $ROOT/source/etc/modules/mod_learnspells.conf
            sed -i 's/LearnSpells.Riding.ColdWeatherFlying =.*/LearnSpells.Riding.ColdWeatherFlying = 0/g' $ROOT/source/etc/modules/mod_learnspells.conf
        else
            if [[ -f $ROOT/source/etc/modules/mod_learnspells.conf.dist ]]; then
                rm -rf $ROOT/source/etc/modules/mod_learnspells.conf.dist
            fi

            if [[ -f $ROOT/source/etc/modules/mod_learnspells.conf ]]; then
                rm -rf $ROOT/source/etc/modules/mod_learnspells.conf
            fi
        fi

        if [[ $RECRUIT_A_FRIEND_ENABLED == "true" ]]; then
            if [[ ! -f $ROOT/source/etc/modules/mod_recruitafriend.conf.dist ]]; then
                printf "${COLOR_RED}The config file mod_recruitafriend.conf.dist is missing.${COLOR_END}\n"
                printf "${COLOR_RED}Please make sure to install the server first.${COLOR_END}\n"
                notify_telegram "$ERROR_UPDATE_CONFIG"
                exit $?
            fi

            printf "${COLOR_ORANGE}Updating mod_recruitafriend.conf${COLOR_END}\n"

            cp $ROOT/source/etc/modules/mod_recruitafriend.conf.dist $ROOT/source/etc/modules/mod_recruitafriend.conf

            sed -i 's/RecruitAFriend.Duration =.*/RecruitAFriend.Duration = 90/g' $ROOT/source/etc/modules/mod_recruitafriend.conf
            sed -i 's/RecruitAFriend.MaxAccountAge =.*/RecruitAFriend.MaxAccountAge = 7/g' $ROOT/source/etc/modules/mod_recruitafriend.conf
            sed -i 's/RecruitAFriend.Rewards.Days =.*/RecruitAFriend.Rewards.Days = 30/g' $ROOT/source/etc/modules/mod_recruitafriend.conf
            sed -i 's/RecruitAFriend.Rewards.SwiftZhevra =.*/RecruitAFriend.Rewards.SwiftZhevra = 1/g' $ROOT/source/etc/modules/mod_recruitafriend.conf
            sed -i 's/RecruitAFriend.Rewards.TouringRocket =.*/RecruitAFriend.Rewards.TouringRocket = 1/g' $ROOT/source/etc/modules/mod_recruitafriend.conf
            sed -i 's/RecruitAFriend.Rewards.CelestialSteed =.*/RecruitAFriend.Rewards.CelestialSteed = 1/g' $ROOT/source/etc/modules/mod_recruitafriend.conf
        else
            if [[ -f $ROOT/source/etc/modules/mod_recruitafriend.conf.dist ]]; then
                rm -rf $ROOT/source/etc/modules/mod_recruitafriend.conf.dist
            fi

            if [[ -f $ROOT/source/etc/modules/mod_recruitafriend.conf ]]; then
                rm -rf $ROOT/source/etc/modules/mod_recruitafriend.conf
            fi
        fi

        if [[ $PLAYER_BOTS_ENABLED == "true" ]]; then
            if [[ ! -f $ROOT/source/etc/modules/playerbots.conf.dist ]]; then
                printf "${COLOR_RED}The config file playerbots.conf.dist is missing.${COLOR_END}\n"
                printf "${COLOR_RED}Please make sure to install the server first.${COLOR_END}\n"
                notify_telegram $ERROR_UPDATE_CONFIG
                exit $?
            fi

            printf "${COLOR_ORANGE}Updating playerbots.conf${COLOR_END}\n"

            cp $ROOT/source/etc/modules/playerbots.conf.dist $ROOT/source/etc/modules/playerbots.conf

            sed -i 's/AiPlayerbot.MinRandomBots =.*/AiPlayerbot.MinRandomBots = '$PLAYER_BOTS_RANDOM_BOTS'/g' $ROOT/source/etc/modules/playerbots.conf
            sed -i 's/AiPlayerbot.MaxRandomBots =.*/AiPlayerbot.MaxRandomBots = '$PLAYER_BOTS_RANDOM_BOTS'/g' $ROOT/source/etc/modules/playerbots.conf
            if [[ $PROGRESSION_ACTIVE_PATCH -lt 12 ]]; then
                sed -i 's/AiPlayerbot.RandomBotMaxLevel =.*/AiPlayerbot.RandomBotMaxLevel = 60/g' $ROOT/source/etc/modules/playerbots.conf
            elif [[ $PROGRESSION_ACTIVE_PATCH -lt 17 ]]; then
                sed -i 's/AiPlayerbot.RandomBotMaxLevel =.*/AiPlayerbot.RandomBotMaxLevel = 70/g' $ROOT/source/etc/modules/playerbots.conf
            else
                sed -i 's/AiPlayerbot.RandomBotMaxLevel =.*/AiPlayerbot.RandomBotMaxLevel = 80/g' $ROOT/source/etc/modules/playerbots.conf
            fi
            sed -i 's/AiPlayerbot.RandomBotAccountCount =.*/AiPlayerbot.RandomBotAccountCount = '$PLAYER_BOTS_RANDOM_BOT_ACCOUNTS'/g' $ROOT/source/etc/modules/playerbots.conf
            sed -i 's/AiPlayerbot.DisableRandomLevels =.*/AiPlayerbot.DisableRandomLevels = 1/g' $ROOT/source/etc/modules/playerbots.conf
            sed -i 's/AiPlayerbot.RandombotStartingLevel =.*/AiPlayerbot.RandombotStartingLevel = 1/g' $ROOT/source/etc/modules/playerbots.conf
            sed -i 's/AiPlayerbot.RandomBotGroupNearby =.*/AiPlayerbot.RandomBotGroupNearby = 1/g' $ROOT/source/etc/modules/playerbots.conf
            sed -i 's/AiPlayerbot.EquipmentPersistence =.*/AiPlayerbot.EquipmentPersistence = 1/g' $ROOT/source/etc/modules/playerbots.conf
            if [[ $PROGRESSION_ACTIVE_PATCH -lt 12 ]]; then
                sed -i 's/AiPlayerbot.EquipmentPersistenceLevel =.*/AiPlayerbot.EquipmentPersistenceLevel = 60/g' $ROOT/source/etc/modules/playerbots.conf
            elif [[ $PROGRESSION_ACTIVE_PATCH -lt 17 ]]; then
                sed -i 's/AiPlayerbot.EquipmentPersistenceLevel =.*/AiPlayerbot.EquipmentPersistenceLevel = 70/g' $ROOT/source/etc/modules/playerbots.conf
            else
                sed -i 's/AiPlayerbot.EquipmentPersistenceLevel =.*/AiPlayerbot.EquipmentPersistenceLevel = 80/g' $ROOT/source/etc/modules/playerbots.conf
            fi
            if [[ $PROGRESSION_ACTIVE_PATCH -lt 12 ]]; then
                sed -i 's/AiPlayerbot.RandomBotMaps =.*/AiPlayerbot.RandomBotMaps = 0,1/g' $ROOT/source/etc/modules/playerbots.conf
            elif [[ $PROGRESSION_ACTIVE_PATCH -lt 17 ]]; then
                sed -i 's/AiPlayerbot.RandomBotMaps =.*/AiPlayerbot.RandomBotMaps = 0,1,530/g' $ROOT/source/etc/modules/playerbots.conf
            else
                sed -i 's/AiPlayerbot.RandomBotMaps =.*/AiPlayerbot.RandomBotMaps = 0,1,530,571/g' $ROOT/source/etc/modules/playerbots.conf
            fi
            sed -i 's/AiPlayerbot.PvpProhibitedZoneIds =.*/AiPlayerbot.PvpProhibitedZoneIds = "4298,2255,656,2361,2362,2363,976,35,2268,3425,392,541,1446,3828,3712,3738,3565,3539,3623,4152,3988,4658,4284,4418,4436,4275,4323,4395,3703"/g' $ROOT/source/etc/modules/playerbots.conf
            sed -i 's/PlayerbotsDatabaseInfo =.*/PlayerbotsDatabaseInfo = "'$MYSQL_HOSTNAME';'$MYSQL_PORT';'$MYSQL_USERNAME';'$MYSQL_PASSWORD';'$PLAYER_BOTS_DATABASE'"/g' $ROOT/source/etc/modules/playerbots.conf
        else
            if [[ -f $ROOT/source/etc/modules/playerbots.conf.dist ]]; then
                rm -rf $ROOT/source/etc/modules/playerbots.conf.dist
            fi

            if [[ -f $ROOT/source/etc/modules/playerbots.conf ]]; then
                rm -rf $ROOT/source/etc/modules/playerbots.conf
            fi
        fi

        if [[ $WEEKEND_BONUS_ENABLED == "true" ]]; then
            if [[ ! -f $ROOT/source/etc/modules/mod_weekendbonus.conf.dist ]]; then
                printf "${COLOR_RED}The config file mod_weekendbonus.conf.dist is missing.${COLOR_END}\n"
                printf "${COLOR_RED}Please make sure to install the server first.${COLOR_END}\n"
                notify_telegram "$ERROR_UPDATE_CONFIG"
                exit $?
            fi

            printf "${COLOR_ORANGE}Updating mod_weekendbonus.conf${COLOR_END}\n"

            cp $ROOT/source/etc/modules/mod_weekendbonus.conf.dist $ROOT/source/etc/modules/mod_weekendbonus.conf

            sed -i 's/WeekendBonus.Multiplier.Experience =.*/WeekendBonus.Multiplier.Experience = 2.0/g' $ROOT/source/etc/modules/mod_weekendbonus.conf
            sed -i 's/WeekendBonus.Multiplier.Money =.*/WeekendBonus.Multiplier.Money = 2.0/g' $ROOT/source/etc/modules/mod_weekendbonus.conf
            sed -i 's/WeekendBonus.Multiplier.Professions =.*/WeekendBonus.Multiplier.Professions = 2/g' $ROOT/source/etc/modules/mod_weekendbonus.conf
            sed -i 's/WeekendBonus.Multiplier.Reputation =.*/WeekendBonus.Multiplier.Reputation = 2.0/g' $ROOT/source/etc/modules/mod_weekendbonus.conf
            sed -i 's/WeekendBonus.Multiplier.Proficiencies =.*/WeekendBonus.Multiplier.Proficiencies = 2/g' $ROOT/source/etc/modules/mod_weekendbonus.conf
        else
            if [[ -f $ROOT/source/etc/modules/mod_weekendbonus.conf.dist ]]; then
                rm -rf $ROOT/source/etc/modules/mod_weekendbonus.conf.dist
            fi

            if [[ -f $ROOT/source/etc/modules/mod_weekendbonus.conf ]]; then
                rm -rf $ROOT/source/etc/modules/mod_weekendbonus.conf
            fi
        fi
    fi

    printf "${COLOR_GREEN}Finished updating the config files...${COLOR_END}\n"
}

function start_server
{
    printf "${COLOR_GREEN}Starting the server...${COLOR_END}\n"

    if [[ ! -f $ROOT/source/bin/start.sh ]] || [[ ! -f $ROOT/source/bin/stop.sh ]]; then
        printf "${COLOR_RED}The required binaries are missing.${COLOR_END}\n"
        printf "${COLOR_RED}Please make sure to install the server first.${COLOR_END}\n"
    else
        if [[ ! -z `screen -list | grep -E "auth"` && -f $ROOT/source/bin/auth.sh ]] || [[ ! -z `screen -list | grep -E "world-$WORLD_ID"` && -f $ROOT/source/bin/world.sh ]]; then
            printf "${COLOR_RED}The server is already running.${COLOR_END}\n"
        else
            cd $ROOT/source/bin && ./start.sh

            if [[ ! -z `screen -list | grep -E "auth"` && -f $ROOT/source/bin/auth.sh ]]; then
                printf "${COLOR_ORANGE}To access the screen of the authserver, use the command ${COLOR_BLUE}screen -r auth${COLOR_ORANGE}.${COLOR_END}\n"
            fi

            if [[ ! -z `screen -list | grep -E "world-$WORLD_ID"` && -f $ROOT/source/bin/world.sh ]]; then
                printf "${COLOR_ORANGE}To access the screen of the worldserver, use the command ${COLOR_BLUE}screen -r world-$WORLD_ID${COLOR_ORANGE}.${COLOR_END}\n"
            fi
        fi
    fi

    printf "${COLOR_GREEN}Finished starting the server...${COLOR_END}\n"
}

function stop_server
{
    printf "${COLOR_GREEN}Stopping the server...${COLOR_END}\n"

    if [[ -z `screen -list | grep -E "auth"` || ! -f $ROOT/source/bin/auth.sh ]] && [[ -z `screen -list | grep -E "world-$WORLD_ID"` || ! -f $ROOT/source/bin/world.sh ]]; then
        printf "${COLOR_RED}The server is not running.${COLOR_END}\n"
    else
        if [[ ! -z `screen -list | grep -E "world-$WORLD_ID"` && -f $ROOT/source/bin/world.sh ]]; then
            printf "${COLOR_ORANGE}Telling the world server to shut down.${COLOR_END}\n"

            PID=$(screen -ls | grep -oE "[0-9]+\.world-$WORLD_ID" | sed -e "s/\..*$//g")

            if [[ $PID != "" ]]; then
                if [[ $1 == "restart" ]]; then
                    screen -S world-$WORLD_ID -p 0 -X stuff "server restart 10^m"
                else
                    screen -S world-$WORLD_ID -p 0 -X stuff "server shutdown 10^m"
                fi

                timeout 30 tail --pid=$PID -f /dev/null
            fi
        fi

        if [[ -f $ROOT/source/bin/stop.sh ]]; then
            cd $ROOT/source/bin && ./stop.sh
        fi
    fi

    printf "${COLOR_GREEN}Finished stopping the server...${COLOR_END}\n"
}

function notify_telegram
{
    if [[ $TELEGRAM_TOKEN != "" ]] && [[ $TELEGRAM_CHAT_ID != "" ]]; then
        curl -s -X POST https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage -d chat_id=$TELEGRAM_CHAT_ID -d text="[$WORLD_NAME (ID: $WORLD_ID)]: $1" > /dev/null
    fi
}

function parameters
{
    printf "${COLOR_GREEN}Available parameters${COLOR_END}\n"
    printf "${COLOR_ORANGE}auth                             ${COLOR_WHITE}| ${COLOR_BLUE}Use chosen subparameters only for the authserver${COLOR_END}\n"
    printf "${COLOR_ORANGE}world                            ${COLOR_WHITE}| ${COLOR_BLUE}Use chosen subparameters only for the worldserver${COLOR_END}\n"
    printf "${COLOR_ORANGE}both                             ${COLOR_WHITE}| ${COLOR_BLUE}Use chosen subparameters for the auth and worldserver${COLOR_END}\n"
    printf "${COLOR_ORANGE}start                            ${COLOR_WHITE}| ${COLOR_BLUE}Starts the compiled processes, based off of the choice for compilation${COLOR_END}\n"
    printf "${COLOR_ORANGE}stop                             ${COLOR_WHITE}| ${COLOR_BLUE}Stops the compiled processes, based off of the choice for compilation${COLOR_END}\n"
    printf "${COLOR_ORANGE}restart                          ${COLOR_WHITE}| ${COLOR_BLUE}Stops and then starts the compiled processes, based off of the choice for compilation${COLOR_END}\n\n"

    printf "${COLOR_GREEN}Available subparameters${COLOR_END}\n"
    printf "${COLOR_ORANGE}install/update                   ${COLOR_WHITE}| ${COLOR_BLUE}Downloads the source code, with enabled modules, and compiles it. Also downloads client files${COLOR_END}\n"
    printf "${COLOR_ORANGE}database/db                      ${COLOR_WHITE}| ${COLOR_BLUE}Import all files to the specified databases${COLOR_END}\n"
    printf "${COLOR_ORANGE}dbc                              ${COLOR_WHITE}| ${COLOR_BLUE}Copy modified client data files to the proper folder${COLOR_END}\n"
    printf "${COLOR_ORANGE}config/conf/cfg/settings/options ${COLOR_WHITE}| ${COLOR_BLUE}Updates all config files, including enabled modules, with options specified${COLOR_END}\n"
    printf "${COLOR_ORANGE}all                              ${COLOR_WHITE}| ${COLOR_BLUE}Run all subparameters listed above, including stop and start${COLOR_END}\n"

    exit $?
}

if [[ $# -gt 0 ]]; then
    if [[ $1 == "both" ]] || [[ $1 == "auth" ]] || [[ $1 == "world" ]]; then
        if [[ $2 == "install" ]] || [[ $2 == "setup" ]] || [[ $2 == "update" ]]; then
            stop_server
            install_packages
            get_source $1
            compile_source $1
            get_client_files $1
        elif [[ $2 == "database" ]] || [[ $2 == "db" ]]; then
            import_database_files $1
        elif [[ $2 == "dbc" ]]; then
            copy_dbc_files $1
        elif [[ $2 == "config" ]] || [[ $2 == "conf" ]] || [[ $2 == "cfg" ]] || [[ $2 == "settings" ]] || [[ $2 == "options" ]]; then
            set_config $1
        elif [[ $2 == "all" ]]; then
            stop_server
            install_packages
            get_source $1
            compile_source $1
            import_database_files $1
            get_client_files $1
            copy_dbc_files $1
            set_config $1
            start_server
        else
            parameters
        fi
    elif [[ $1 == "start" ]]; then
        start_server
    elif [[ $1 == "stop" ]]; then
        stop_server $1
    elif [[ $1 == "restart" ]]; then
        stop_server $1
        start_server
    else
        parameters
    fi
else
    parameters
fi