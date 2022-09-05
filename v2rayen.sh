#!/bin/bash

export LC_ALL=C
#export LANG=C
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8


sudoCmd=""
if [[ $(/usr/bin/id -u) -ne 0 ]]; then
  sudoCmd="sudo"
fi


uninstall() {
    ${sudoCmd} "$(which rm)" -rf $1
    printf "File or Folder Deleted: %s\n" $1
}


# fonts color
red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}
green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}
blue(){
    echo -e "\033[34m\033[01m$1\033[0m"
}
bold(){
    echo -e "\033[1m\033[01m$1\033[0m"
}




osCPU=""
osArchitecture="arm"
osInfo=""
osRelease=""
osReleaseVersion=""
osReleaseVersionNo=""
osReleaseVersionNoShort=""
osReleaseVersionCodeName="CodeName"
osSystemPackage=""
osSystemMdPath=""
osSystemShell="bash"


function checkArchitecture(){
	# https://stackoverflow.com/questions/48678152/how-to-detect-386-amd64-arm-or-arm64-os-architecture-via-shell-bash

	case $(uname -m) in
		i386)   osArchitecture="386" ;;
		i686)   osArchitecture="386" ;;
		x86_64) osArchitecture="amd64" ;;
		arm)    dpkg --print-architecture | grep -q "arm64" && osArchitecture="arm64" || osArchitecture="arm" ;;
		aarch64)    dpkg --print-architecture | grep -q "arm64" && osArchitecture="arm64" || osArchitecture="arm" ;;
		* )     osArchitecture="arm" ;;
	esac
}


function checkCPU(){
	osCPUText=$(cat /proc/cpuinfo | grep vendor_id | uniq)
	if [[ $osCPUText =~ "GenuineIntel" ]]; then
		osCPU="intel"
    elif [[ $osCPUText =~ "AMD" ]]; then
        osCPU="amd"
    else
        echo
    fi

	# green " Status display -- current CPU is: $osCPU"
}

# Detect system version number
getLinuxOSVersion(){
    if [[ -s /etc/redhat-release ]]; then
        osReleaseVersion=$(grep -oE '[0-9.]+' /etc/redhat-release)
    else
        osReleaseVersion=$(grep -oE '[0-9.]+' /etc/issue)
    fi

    # https://unix.stackexchange.com/questions/6345/how-can-i-get-distribution-name-and-version-number-in-a-simple-shell-script

    if [ -f /etc/os-release ]; then
        # freedesktop.org and systemd
        source /etc/os-release
        osInfo=$NAME
        osReleaseVersionNo=$VERSION_ID

        if [ -n "$VERSION_CODENAME" ]; then
            osReleaseVersionCodeName=$VERSION_CODENAME
        fi
    elif type lsb_release >/dev/null 2>&1; then
        # linuxbase.org
        osInfo=$(lsb_release -si)
        osReleaseVersionNo=$(lsb_release -sr)

    elif [ -f /etc/lsb-release ]; then
        # For some versions of Debian/Ubuntu without lsb_release command
        . /etc/lsb-release
        osInfo=$DISTRIB_ID
        osReleaseVersionNo=$DISTRIB_RELEASE
        
    elif [ -f /etc/debian_version ]; then
        # Older Debian/Ubuntu/etc.
        osInfo=Debian
        osReleaseVersion=$(cat /etc/debian_version)
        osReleaseVersionNo=$(sed 's/\..*//' /etc/debian_version)
    elif [ -f /etc/redhat-release ]; then
        osReleaseVersion=$(grep -oE '[0-9.]+' /etc/redhat-release)
    else
        # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
        osInfo=$(uname -s)
        osReleaseVersionNo=$(uname -r)
    fi

    osReleaseVersionNoShort=$(echo $osReleaseVersionNo | sed 's/\..*//')
}

# Detect system release code
function getLinuxOSRelease(){
    if [[ -f /etc/redhat-release ]]; then
        osRelease="centos"
        osSystemPackage="yum"
        osSystemMdPath="/usr/lib/systemd/system/"
        osReleaseVersionCodeName=""
    elif cat /etc/issue | grep -Eqi "debian|raspbian"; then
        osRelease="debian"
        osSystemPackage="apt-get"
        osSystemMdPath="/lib/systemd/system/"
        osReleaseVersionCodeName="buster"
    elif cat /etc/issue | grep -Eqi "ubuntu"; then
        osRelease="ubuntu"
        osSystemPackage="apt-get"
        osSystemMdPath="/lib/systemd/system/"
        osReleaseVersionCodeName="bionic"
    elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
        osRelease="centos"
        osSystemPackage="yum"
        osSystemMdPath="/usr/lib/systemd/system/"
        osReleaseVersionCodeName=""
    elif cat /proc/version | grep -Eqi "debian|raspbian"; then
        osRelease="debian"
        osSystemPackage="apt-get"
        osSystemMdPath="/lib/systemd/system/"
        osReleaseVersionCodeName="buster"
    elif cat /proc/version | grep -Eqi "ubuntu"; then
        osRelease="ubuntu"
        osSystemPackage="apt-get"
        osSystemMdPath="/lib/systemd/system/"
        osReleaseVersionCodeName="bionic"
    elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
        osRelease="centos"
        osSystemPackage="yum"
        osSystemMdPath="/usr/lib/systemd/system/"
        osReleaseVersionCodeName=""
    fi

    getLinuxOSVersion
    checkArchitecture
	checkCPU

    [[ -z $(echo $SHELL|grep zsh) ]] && osSystemShell="bash" || osSystemShell="zsh"

    green " OS info: ${osInfo}, ${osRelease}, ${osReleaseVersion}, ${osReleaseVersionNo}, ${osReleaseVersionCodeName}, ${osCPU} CPU ${osArchitecture}, ${osSystemShell}, ${osSystemPackage}, ${osSystemMdPath}"
}




function promptContinueOpeartion(){
	read -p "Do you want to continue the operation? Press Enter to continue the operation by default, please enter [Y/n]:" isContinueInput
	isContinueInput=${isContinueInput:-Y}

	if [[ $isContinueInput == [Yy] ]]; then
		echo ""
	else 
		exit 1
	fi
}

osPort80=""
osPort443=""
osSELINUXCheck=""
osSELINUXCheckIsRebootInput=""

function testLinuxPortUsage(){
    $osSystemPackage -y install net-tools socat

    osPort80=$(netstat -tlpn | awk -F '[: ]+' '$1=="tcp"{print $5}' | grep -w 80)
    osPort443=$(netstat -tlpn | awk -F '[: ]+' '$1=="tcp"{print $5}' | grep -w 443)

    if [ -n "$osPort80" ]; then
        process80=$(netstat -tlpn | awk -F '[: ]+' '$5=="80"{print $9}')
        red "==========================================================="
        red "Detected that port 80 is occupied, the occupied process is: ${process80} "
        red "==========================================================="
        promptContinueOpeartion
    fi

    if [ -n "$osPort443" ]; then
        process443=$(netstat -tlpn | awk -F '[: ]+' '$5=="443"{print $9}')
        red "============================================================="
        red "Detected that port 443 is occupied, the occupied process is: ${process443} "
        red "============================================================="
        promptContinueOpeartion
    fi

    osSELINUXCheck=$(grep SELINUX= /etc/selinux/config | grep -v "#")
    if [ "$osSELINUXCheck" == "SELINUX=enforcing" ]; then
        red "======================================================================="
        red "Detected that SELinux is in mandatory mode, SELinux will be turned off to prevent failure to apply for a certificate. Please restart the VPS before executing this script"
        red "======================================================================="
        read -p "Reboot now? Please enter [Y/n] :" osSELINUXCheckIsRebootInput
        [ -z "${osSELINUXCheckIsRebootInput}" ] && osSELINUXCheckIsRebootInput="y"

        if [[ $osSELINUXCheckIsRebootInput == [Yy] ]]; then
            sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
            setenforce 0
            echo -e "VPS restarting..."
            reboot
        fi
        exit
    fi

    if [ "$osSELINUXCheck" == "SELINUX=permissive" ]; then
        red "======================================================================="
        red "Detected that SELinux is in permissive mode. In order to prevent the failure to apply for a certificate, SELinux will be turned off. Please restart the VPS before executing this script"
        red "======================================================================="
        read -p "Reboot now? Please enter [Y/n] :" osSELINUXCheckIsRebootInput
        [ -z "${osSELINUXCheckIsRebootInput}" ] && osSELINUXCheckIsRebootInput="y"

        if [[ $osSELINUXCheckIsRebootInput == [Yy] ]]; then
            sed -i 's/SELINUX=permissive/SELINUX=disabled/g' /etc/selinux/config
            setenforce 0
            echo -e "VPS restarting..."
            reboot
        fi
        exit
    fi

    if [ "$osRelease" == "centos" ]; then
        if  [[ ${osReleaseVersionNoShort} == "6" || ${osReleaseVersionNoShort} == "5" ]]; then
            green " =================================================="
            red "This script does not support Centos 6 or earlier versions of Centos 6"
            green " =================================================="
            exit
        fi

        red "turn off firewalld"
        ${sudoCmd} systemctl stop firewalld
        ${sudoCmd} systemctl disable firewalld

    elif [ "$osRelease" == "ubuntu" ]; then
        if  [[ ${osReleaseVersionNoShort} == "14" || ${osReleaseVersionNoShort} == "12" ]]; then
            green " =================================================="
            red "This script does not support Ubuntu 14 or earlier versions of Ubuntu 14"
            green " =================================================="
            exit
        fi

        red "turn off firewall ufw"
        ${sudoCmd} systemctl stop ufw
        ${sudoCmd} systemctl disable ufw

        ufw disable
        
    elif [ "$osRelease" == "debian" ]; then
        $osSystemPackage update -y
    fi

}










# Edit SSH public key file for password-free login
function editLinuxLoginWithPublicKey(){
    if [ ! -d "${HOME}/ssh" ]; then
        mkdir -p ${HOME}/.ssh
    fi

    vi ${HOME}/.ssh/authorized_keys
}



# Set up SSH root login

function setLinuxRootLogin(){

    read -p "Are you set to allow root login (ssh key or password login)? Please input [Y/n]:" osIsRootLoginInput
    osIsRootLoginInput=${osIsRootLoginInput:-Y}

    if [[ $osIsRootLoginInput == [Yy] ]]; then

        if [ "$osRelease" == "centos" ] || [ "$osRelease" == "debian" ] ; then
            ${sudoCmd} sed -i 's/#\?PermitRootLogin \(yes\|no\|Yes\|No\|prohibit-password\)/PermitRootLogin yes/g' /etc/ssh/sshd_config
        fi
        if [ "$osRelease" == "ubuntu" ]; then
            ${sudoCmd} sed -i 's/#\?PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config
        fi

        green "Set to allow root login success!"
    fi


    read -p "Do you want to allow root to log in with a password (in the previous step, please allow root to log in)? Please enter [Y/n]:" osIsRootLoginWithPasswordInput
    osIsRootLoginWithPasswordInput=${osIsRootLoginWithPasswordInput:-Y}

    if [[ $osIsRootLoginWithPasswordInput == [Yy] ]]; then
        sed -i 's/#\?PasswordAuthentication \(yes\|no\)/PasswordAuthentication yes/g' /etc/ssh/sshd_config
        green "Set to allow root to use password to log in successfully!"
    fi


    ${sudoCmd} sed -i 's/#\?TCPKeepAlive yes/TCPKeepAlive yes/g' /etc/ssh/sshd_config
    ${sudoCmd} sed -i 's/#\?ClientAliveCountMax 3/ClientAliveCountMax 30/g' /etc/ssh/sshd_config
    ${sudoCmd} sed -i 's/#\?ClientAliveInterval [0-9]*/ClientAliveInterval 40/g' /etc/ssh/sshd_config

    if [ "$osRelease" == "centos" ] ; then

        ${sudoCmd} service sshd restart
        ${sudoCmd} systemctl restart sshd

        green "The setting is successful, please use the shell tool software to log in to the vps server!"
    fi

    if [ "$osRelease" == "ubuntu" ] || [ "$osRelease" == "debian" ] ; then
        
        ${sudoCmd} service ssh restart
        ${sudoCmd} systemctl restart ssh

        green "The setting is successful, please use the shell tool software to log in to the vps server!"
    fi

    # /etc/init.d/ssh restart
}


# Modify the SSH port number
function changeLinuxSSHPort(){
    green "Modified port number for SSH login, do not use commonly used port numbers. For example 20|21|23|25|53|69|80|110|443|123!"
    read -p "Please enter the port number to be modified (must be a pure number and between 1024~65535 or 22):" osSSHLoginPortInput
    osSSHLoginPortInput=${osSSHLoginPortInput:-0}

    if [ $osSSHLoginPortInput -eq 22 -o $osSSHLoginPortInput -gt 1024 -a $osSSHLoginPortInput -lt 65535 ]; then
        sed -i "s/#\?Port [0-9]*/Port $osSSHLoginPortInput/g" /etc/ssh/sshd_config

        if [ "$osRelease" == "centos" ] ; then

            if  [[ ${osReleaseVersionNoShort} == "7" ]]; then
                yum -y install policycoreutils-python
            elif  [[ ${osReleaseVersionNoShort} == "8" ]]; then
                yum -y install policycoreutils-python-utils
            fi

            # semanage port -l
            semanage port -a -t ssh_port_t -p tcp ${osSSHLoginPortInput}
            if command -v firewall-cmd &> /dev/null; then
                firewall-cmd --permanent --zone=public --add-port=$osSSHLoginPortInput/tcp 
                firewall-cmd --reload
            fi
    
            ${sudoCmd} systemctl restart sshd.service

        fi

        if [ "$osRelease" == "ubuntu" ] || [ "$osRelease" == "debian" ] ; then
            semanage port -a -t ssh_port_t -p tcp $osSSHLoginPortInput
            ${sudoCmd} ufw allow $osSSHLoginPortInput/tcp

            ${sudoCmd} service ssh restart
            ${sudoCmd} systemctl restart ssh
        fi

        green "Set successfully, please remember the set port number ${osSSHLoginPortInput}!"
        green "Login server command: ssh -p ${osSSHLoginPortInput} root@111.111.111.your ip !"
    else
        echo "The input port number is wrong! Range: 22,1025~65534"
    fi
}


# Set Beijing time zone
function setLinuxDateZone(){

    tempCurrentDateZone=$(date +'%z')

    echo
    if [[ ${tempCurrentDateZone} == "+0800" ]]; then
        yellow "The current time zone is already Beijing time $tempCurrentDateZone | $(date -R) "
    else 
        green " =================================================="
        yellow "The current time zone is: $tempCurrentDateZone | $(date -R) "
        yellow "Whether to set the time zone to Beijing time + 0800 zone, so that the cron restart script will run according to Beijing time."
        green " =================================================="
        # read default value https://stackoverflow.com/questions/2642585/read-a-variable-in-bash-with-a-default-value

        read -p "Is it set to Beijing time + 0800 time zone? Please input [Y/n]:" osTimezoneInput
        osTimezoneInput=${osTimezoneInput:-Y}

        if [[ $osTimezoneInput == [Yy] ]]; then
            if [[ -f /etc/localtime ]] && [[ -f /usr/share/zoneinfo/Asia/Shanghai ]]; then
                mv /etc/localtime /etc/localtime.bak
                cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

                yellow "Set successfully! Current time zone is set to $(date -R)"
                green " =================================================="
            fi
        fi

    fi
    echo

    if [ "$osRelease" == "centos" ]; then   
        if  [[ ${osReleaseVersionNoShort} == "7" ]]; then
            systemctl stop chronyd
            systemctl disable chronyd

            $osSystemPackage -y install ntpdate
            $osSystemPackage -y install ntp
            ntpdate -q 0.rhel.pool.ntp.org
            systemctl enable ntpd
            systemctl restart ntpd
            ntpdate -u  pool.ntp.org

        elif  [[ ${osReleaseVersionNoShort} == "8" || ${osReleaseVersionNoShort} == "9" ]]; then
            $osSystemPackage -y install chrony
            systemctl enable chronyd
            systemctl restart chronyd

            if command -v firewall-cmd &> /dev/null; then
                firewall-cmd --permanent --add-service=ntp
                firewall-cmd --reload
            fi 

            chronyc sources

            echo
        fi
        
    else
        $osSystemPackage install -y ntp
        systemctl enable ntp
        systemctl restart ntp
    fi    
}








# Software Installation
function installSoftDownload(){
	if [[ "${osRelease}" == "debian" || "${osRelease}" == "ubuntu" ]]; then
		if ! dpkg -l | grep -qw wget; then
			${osSystemPackage} -y install wget git unzip curl apt-transport-https
			
			# https://stackoverflow.com/questions/11116704/check-if-vt-x-is-activated-without-having-to-reboot-in-linux
			${osSystemPackage} -y install cpu-checker
		fi

		if ! dpkg -l | grep -qw curl; then
			${osSystemPackage} -y install curl git unzip wget apt-transport-https
			
			${osSystemPackage} -y install cpu-checker
		fi

	elif [[ "${osRelease}" == "centos" ]]; then

        if  [[ ${osReleaseVersion} == "8.1.1911" || ${osReleaseVersion} == "8.2.2004" || ${osReleaseVersion} == "8.0.1905" || ${osReleaseVersion} == "8.5.2111" ]]; then

            # https://techglimpse.com/failed-metadata-repo-appstream-centos-8/

            cd /etc/yum.repos.d/
            sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*
            sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*
            yum update -y

            sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-Linux-*
            sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-Linux-*

            ${sudoCmd} dnf install centos-release-stream -y
            ${sudoCmd} dnf swap centos-{linux,stream}-repos -y
            ${sudoCmd} dnf distro-sync -y
        fi
        
        if ! rpm -qa | grep -qw wget; then
		    ${osSystemPackage} -y install wget curl git unzip

        elif ! rpm -qa | grep -qw git; then
		    ${osSystemPackage} -y install wget curl git unzip
		fi
	fi
}


function installPackage(){
    echo
    green " =================================================="
    yellow "Start installing software"
    green " =================================================="
    echo

    # sed -i '1s/^/nameserver 1.1.1.1 \n/' /etc/resolv.conf

    if [ "$osRelease" == "centos" ]; then
       
        # rpm -Uvh http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm
        rm -f /etc/yum.repos.d/nginx.repo
        # cat > "/etc/yum.repos.d/nginx.repo" <<-EOF
# [nginx]
# name=nginx repo
# baseurl=https://nginx.org/packages/centos/$osReleaseVersionNoShort/\$basearch/
# gpgcheck=0
# enabled=1
# sslverify=0
# 
# EOF

        if ! rpm -qa | grep -qw iperf3; then
			${sudoCmd} ${osSystemPackage} install -y epel-release

            ${osSystemPackage} install -y curl wget git unzip zip tar bind-utils htop net-tools
            ${osSystemPackage} install -y xz jq redhat-lsb-core 
            ${osSystemPackage} install -y iputils
            ${osSystemPackage} install -y iperf3
		fi

        ${osSystemPackage} update -y


        # https://www.cyberciti.biz/faq/how-to-install-and-use-nginx-on-centos-8/
        if  [[ ${osReleaseVersionNoShort} == "8" || ${osReleaseVersionNoShort} == "9" ]]; then
            ${sudoCmd} yum module -y reset nginx
            ${sudoCmd} yum module -y enable nginx:1.20
            ${sudoCmd} yum module list nginx
        fi

    elif [ "$osRelease" == "ubuntu" ]; then
        
        # https://joshtronic.com/2018/12/17/how-to-install-the-latest-nginx-on-debian-and-ubuntu/
        # https://www.nginx.com/resources/wiki/start/topics/tutorials/install/
        
        $osSystemPackage install -y gnupg2 curl ca-certificates lsb-release ubuntu-keyring
        # wget -O - https://nginx.org/keys/nginx_signing.key | ${sudoCmd} apt-key add -
        curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor | sudo tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null

        rm -f /etc/apt/sources.list.d/nginx.list

        cat > "/etc/apt/sources.list.d/nginx.list" <<-EOF
deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg]   https://nginx.org/packages/ubuntu/ $osReleaseVersionCodeName nginx
# deb [arch=amd64] https://nginx.org/packages/ubuntu/ $osReleaseVersionCodeName nginx
# deb-src https://nginx.org/packages/ubuntu/ $osReleaseVersionCodeName nginx
EOF

        echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n"  | sudo tee /etc/apt/preferences.d/99-nginx

        if [[ "${osReleaseVersionNoShort}" == "22" || "${osReleaseVersionNoShort}" == "21" ]]; then
            echo
        fi



        ${osSystemPackage} update -y

        if ! dpkg -l | grep -qw iperf3; then
            ${sudoCmd} ${osSystemPackage} install -y software-properties-common
            ${osSystemPackage} install -y curl wget git unzip zip tar htop
            ${osSystemPackage} install -y xz-utils jq lsb-core lsb-release
            ${osSystemPackage} install -y iputils-ping
            ${osSystemPackage} install -y iperf3
		fi    

    elif [ "$osRelease" == "debian" ]; then
        # ${sudoCmd} add-apt-repository ppa:nginx/stable -y
        ${osSystemPackage} update -y

        apt install -y gnupg2
        apt install -y curl ca-certificates lsb-release
        wget https://nginx.org/keys/nginx_signing.key -O- | apt-key add - 

        rm -f /etc/apt/sources.list.d/nginx.list
        if [[ "${osReleaseVersionNoShort}" == "12" ]]; then
            echo
        else
            cat > "/etc/apt/sources.list.d/nginx.list" <<-EOF
deb https://nginx.org/packages/mainline/debian/ $osReleaseVersionCodeName nginx
deb-src https://nginx.org/packages/mainline/debian $osReleaseVersionCodeName nginx
EOF
        fi


        ${osSystemPackage} update -y

        if ! dpkg -l | grep -qw iperf3; then
            ${osSystemPackage} install -y curl wget git unzip zip tar htop
            ${osSystemPackage} install -y xz-utils jq lsb-core lsb-release
            ${osSystemPackage} install -y iputils-ping
            ${osSystemPackage} install -y iperf3
        fi        
    fi
}


function installSoftEditor(){
    # install micro editor
    if [[ ! -f "${HOME}/bin/micro" ]] ;  then
        mkdir -p ${HOME}/bin
        cd ${HOME}/bin
        curl https://getmic.ro | bash

        cp ${HOME}/bin/micro /usr/local/bin

        green " =================================================="
        green "Micro editor installed successfully!"
        green " =================================================="
    fi

    if [ "$osRelease" == "centos" ]; then   
        $osSystemPackage install -y xz  vim-minimal vim-enhanced vim-common nano
    else
        $osSystemPackage install -y vim-gui-common vim-runtime vim nano
    fi

    # Set vim Chinese garbled characters
    if [[ ! -d "${HOME}/.vimrc" ]] ;  then
        cat > "${HOME}/.vimrc" <<-EOF
set fileencodings=utf-8,gb2312,gb18030,gbk,ucs-bom,cp936,latin1
set enc=utf8
set fencs=utf8,gbk,gb2312,gb18030

syntax on
colorscheme elflord

if has('mouse')
  se mouse+=a
  set number
endif

EOF
    fi
}

function installSoftOhMyZsh(){

    echo
    green " =================================================="
    yellow "Starting to install ZSH"
    green " =================================================="
    echo

    if [ "$osRelease" == "centos" ]; then

        ${sudoCmd} $osSystemPackage install zsh -y
        $osSystemPackage install util-linux-user -y

    elif [ "$osRelease" == "ubuntu" ]; then

        ${sudoCmd} $osSystemPackage install zsh -y

    elif [ "$osRelease" == "debian" ]; then

        ${sudoCmd} $osSystemPackage install zsh -y
    fi

    green " =================================================="
    green "ZSH installed successfully"
    green " =================================================="

    # install oh-my-zsh
    if [[ ! -d "${HOME}/.oh-my-zsh" ]] ;  then

        green " =================================================="
        yellow "Starting to install oh-my-zsh"
        green " =================================================="
        curl -Lo ${HOME}/ohmyzsh_install.sh https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh
        chmod +x ${HOME}/ohmyzsh_install.sh
        sh ${HOME}/ohmyzsh_install.sh --unattended
    fi

    if [[ ! -d "${HOME}/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]] ;  then
        git clone "https://github.com/zsh-users/zsh-autosuggestions" "${HOME}/.oh-my-zsh/custom/plugins/zsh-autosuggestions"

        # configure zshrc file
        zshConfig=${HOME}/.zshrc
        zshTheme="maran"
        sed -i 's/ZSH_THEME=.*/ZSH_THEME="'"${zshTheme}"'"/' $zshConfig
        sed -i 's/plugins=(git)/plugins=(git cp history z rsync colorize nvm zsh-autosuggestions)/' $zshConfig

        zshAutosuggestionsConfig=${HOME}/.oh-my-zsh/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
        sed -i "s/ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'/ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=1'/" $zshAutosuggestionsConfig


        # Actually change the default shell to zsh
        zsh=$(which zsh)

        if ! chsh -s "$zsh"; then
            red "chsh command unsuccessful. Change your default shell manually."
        else
            export SHELL="$zsh"
            green "===== Shell successfully changed to '$zsh'."
        fi


        echo 'alias ll="ls -ahl"' >> ${HOME}/.zshrc
        echo 'alias mi="micro"' >> ${HOME}/.zshrc

        green " =================================================="
        yellow "The installation of oh-my-zsh is successful, please use the exit command to log out of the server and then log in again!"
        green " =================================================="

    fi

}








# Updated script
function upgradeScript(){
    wget -Nq --no-check-certificate -O ./trojan_v2ray_install.sh "https://raw.githubusercontent.com/jinwyp/one_click_script/master/trojan_v2ray_install.sh"
    green "This script has been successfully upgraded!"
    chmod +x ./trojan_v2ray_install.sh
    sleep 2s
    exec "./trojan_v2ray_install.sh"
}

function installWireguard(){
    bash <(wget -qO- https://github.com/jinwyp/one_click_script/raw/master/install_kernel.sh)
    # wget -N --no-check-certificate https://github.com/jinwyp/one_click_script/raw/master/install_kernel.sh && chmod +x ./install_kernel.sh && ./install_kernel.sh
}



















# network speed test

function vps_netflix(){
    # bash <(curl -sSL https://raw.githubusercontent.com/Netflixxp/NF/main/nf.sh)
    # bash <(curl -sSL "https://github.com/CoiaPrant/Netflix_Unlock_Information/raw/main/netflix.sh")
    # bash <(curl -L -s https://raw.githubusercontent.com/lmc999/RegionRestrictionCheck/main/check.sh)

	# wget -N --no-check-certificate https://github.com/CoiaPrant/Netflix_Unlock_Information/raw/main/netflix.sh && chmod +x netflix.sh && ./netflix.sh
    # wget -N --no-check-certificate -O netflixcheck https://github.com/sjlleo/netflix-verify/releases/download/2.61/nf_2.61_linux_amd64 && chmod +x ./netflixcheck && ./netflixcheck -method full

	wget -N --no-check-certificate -O ./netflix.sh https://github.com/CoiaPrant/MediaUnlock_Test/raw/main/check.sh && chmod +x ./netflix.sh && ./netflix.sh
}

function vps_netflix2(){
	wget -N --no-check-certificate -O ./netflix.sh https://github.com/lmc999/RegionRestrictionCheck/raw/main/check.sh && chmod +x ./netflix.sh && ./netflix.sh
}

function vps_netflix_jin(){
    # wget -qN --no-check-certificate -O ./nf.sh https://raw.githubusercontent.com/jinwyp/SimpleNetflix/dev/nf.sh && chmod +x ./nf.sh
	wget -qN --no-check-certificate -O ./nf.sh https://raw.githubusercontent.com/jinwyp/one_click_script/master/netflix_check.sh && chmod +x ./nf.sh && ./nf.sh
}



function vps_netflixgo(){
    wget -qN --no-check-certificate -O netflixGo https://github.com/sjlleo/netflix-verify/releases/download/v3.1.0/nf_linux_amd64 && chmod +x ./netflixGo && ./netflixGo
    # wget -qN --no-check-certificate -O netflixGo https://github.com/sjlleo/netflix-verify/releases/download/2.61/nf_2.61_linux_amd64 && chmod +x ./netflixGo && ./netflixGo -method full
    echo
    echo
    wget -qN --no-check-certificate -O disneyplusGo https://github.com/sjlleo/VerifyDisneyPlus/releases/download/1.01/dp_1.01_linux_amd64 && chmod +x ./disneyplusGo && ./disneyplusGo
}


function vps_superspeed(){
    bash <(curl -Lso- https://git.io/superspeed_uxh)
    # bash <(curl -Lso- https://git.io/Jlkmw)
    # https://github.com/coolaj/sh/blob/main/speedtest.sh


    # bash <(curl -Lso- https://raw.githubusercontent.com/uxh/superspeed/master/superspeed.sh)

    # bash <(curl -Lso- https://raw.githubusercontent.com/zq/superspeed/master/superspeed.sh)
	# bash <(curl -Lso- https://git.io/superspeed.sh)


    #wget -N --no-check-certificate https://raw.githubusercontent.com/flyzy2005/superspeed/master/superspeed.sh && chmod +x superspeed.sh && ./superspeed.sh
    #wget -N --no-check-certificate https://raw.githubusercontent.com/zq/superspeed/master/superspeed.sh && chmod +x superspeed.sh && ./superspeed.sh

    # bash <(curl -Lso- https://git.io/superspeed)
	#wget -N --no-check-certificate https://raw.githubusercontent.com/ernisn/superspeed/master/superspeed.sh && chmod +x superspeed.sh && ./superspeed.sh
	
	#wget -N --no-check-certificate https://raw.githubusercontent.com/oooldking/script/master/superspeed.sh && chmod +x superspeed.sh && ./superspeed.sh
}

function vps_yabs(){
	curl -sL yabs.sh | bash
}
function vps_bench(){
    wget -N --no-check-certificate https://raw.githubusercontent.com/jinwyp/one_click_script/master/bench.sh && chmod +x bench.sh && bash bench.sh
	# wget -N --no-check-certificate https://raw.githubusercontent.com/teddysun/across/master/bench.sh && chmod +x bench.sh && bash bench.sh
}
function vps_bench_dedicated(){
    # bash -c "$(wget -qO- https://github.com/Aniverse/A/raw/i/a)"
	wget -N --no-check-certificate -O dedicated_server_bench.sh https://raw.githubusercontent.com/Aniverse/A/i/a && chmod +x dedicated_server_bench.sh && bash dedicated_server_bench.sh
}

function vps_zbench(){
	wget -N --no-check-certificate https://raw.githubusercontent.com/FunctionClub/ZBench/master/ZBench-CN.sh && chmod +x ZBench-CN.sh && bash ZBench-CN.sh
}
function vps_LemonBench(){
    wget -N --no-check-certificate -O LemonBench.sh https://ilemonra.in/LemonBenchIntl && chmod +x LemonBench.sh && ./LemonBench.sh fast
}

function vps_testrace(){
	wget -N --no-check-certificate https://raw.githubusercontent.com/nanqinlang-script/testrace/master/testrace.sh && chmod +x testrace.sh && ./testrace.sh
}

function vps_autoBestTrace(){
    wget -N --no-check-certificate -O autoBestTrace.sh https://raw.githubusercontent.com/zq/shell/master/autoBestTrace.sh && chmod +x autoBestTrace.sh && ./autoBestTrace.sh
}
function vps_mtrTrace(){
    curl https://raw.githubusercontent.com/zhucaidan/mtr_trace/main/mtr_trace.sh | bash
}
function vps_returnroute(){
    # https://www.zhujizixun.com/6216.html
    # https://91ai.net/thread-1015693-5-1.html
    # https://github.com/zhucaidan/mtr_trace
    wget --no-check-certificate -O route https://tutu.ovh/bash/returnroute/route  && chmod +x route && ./route
}
function vps_returnroute2(){
    # curl https://raw.githubusercontent.com/zhanghanyun/backtrace/main/install.sh | sh
    wget -N --no-check-certificate -O routeGo.sh https://raw.githubusercontent.com/zhanghanyun/backtrace/main/install.sh && chmod +x routeGo.sh && ./routeGo.sh
}




function installBBR(){
    wget -N --no-check-certificate -O tcp_old.sh "https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh" && chmod +x tcp_old.sh && ./tcp_old.sh
}

function installBBR2(){
    wget -N --no-check-certificate "https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
}





function installBTPanel(){
    if [ "$osRelease" == "centos" ]; then
        yum install -y wget && wget -O install.sh http://download.bt.cn/install/install_6.0.sh && sh install.sh
    else
        # curl -sSO http://download.bt.cn/install/install_panel.sh && bash install_panel.sh
        wget -O install.sh http://download.bt.cn/install/install-ubuntu_6.0.sh && sudo bash install.sh

    fi
}

function installBTPanelCrack(){
    echo "US node (directly enter 11 digits and 1 password at will to log in)"
    if [ "$osRelease" == "centos" ]; then
        yum install -y wget && wget -O btinstall.sh http://io.yu.al/install/install_6.0.sh && sh btinstall.sh
        # yum install -y wget && wget -O install.sh https://download.fenhao.me/install/install_6.0.sh && sh install.sh
    else
        wget -O btinstall.sh http://io.yu.al/install/install_panel.sh && sudo bash btinstall.sh
        #wget -O install.sh https://download.fenhao.me/install/install-ubuntu_6.0.sh && sudo bash install.sh
    fi
}

function installBTPanelCrackHostcli(){
    if [ "$osRelease" == "centos" ]; then
        yum install -y wget && wget -O btinstall.sh http://v7.hostcli.com/install/install_6.0.sh && sh btinstall.sh
    else
        wget -O btinstall.sh http://v7.hostcli.com/install/install-ubuntu_6.0.sh && sudo bash btinstall.sh
    fi
}













































configWebsiteFatherPath="/nginxweb"
configWebsitePath="${configWebsiteFatherPath}/html"
nginxAccessLogFilePath="${configWebsiteFatherPath}/nginx-access.log"
nginxErrorLogFilePath="${configWebsiteFatherPath}/nginx-error.log"

configTrojanWindowsCliPrefixPath=$(cat /dev/urandom | head -1 | md5sum | head -c 20)
configWebsiteDownloadPath="${configWebsitePath}/download/${configTrojanWindowsCliPrefixPath}"
configDownloadTempPath="${HOME}/temp"



versionTrojan="1.16.0"
downloadFilenameTrojan="trojan-${versionTrojan}-linux-amd64.tar.xz"

versionTrojanGo="0.10.5"
downloadFilenameTrojanGo="trojan-go-linux-amd64.zip"

versionV2ray="4.45.2"
downloadFilenameV2ray="v2ray-linux-64.zip"

versionXray="1.5.2"
downloadFilenameXray="Xray-linux-64.zip"

versionTrojanWeb="2.10.5"
downloadFilenameTrojanWeb="trojan-linux-amd64"

isTrojanMultiPassword="no"
promptInfoTrojanName=""
isTrojanGo="yes"
isTrojanGoSupportWebsocket="false"
configTrojanGoWebSocketPath=$(cat /dev/urandom | head -1 | md5sum | head -c 8)
configTrojanPasswordPrefixInputDefault=$(cat /dev/urandom | head -1 | md5sum | head -c 3)

configTrojanPath="${HOME}/trojan"
configTrojanGoPath="${HOME}/trojan-go"
configTrojanWebPath="${HOME}/trojan-web"
configTrojanLogFile="${HOME}/trojan-access.log"
configTrojanGoLogFile="${HOME}/trojan-go-access.log"

configTrojanBasePath=${configTrojanPath}
configTrojanBaseVersion=${versionTrojan}

configTrojanWebNginxPath=$(cat /dev/urandom | head -1 | md5sum | head -c 5)
configTrojanWebPort="$(($RANDOM + 10000))"

configInstallNginxMode=""
nginxConfigPath="/etc/nginx/nginx.conf"


promptInfoXrayInstall="V2ray"
promptInfoXrayVersion=""
promptInfoXrayName="v2ray"
promptInfoXrayNameServiceName=""
isXray="no"

configV2rayWebSocketPath=$(cat /dev/urandom | head -1 | md5sum | head -c 8)
configV2rayGRPCServiceName=$(cat /dev/urandom | head -1 | md5sum | head -c 8)
configV2rayPort="$(($RANDOM + 10000))"
configV2rayGRPCPort="$(($RANDOM + 10000))"
configV2rayVmesWSPort="$(($RANDOM + 10000))"
configV2rayVmessTCPPort="$(($RANDOM + 10000))"
configV2rayPortShowInfo=$configV2rayPort
configV2rayPortGRPCShowInfo=$configV2rayGRPCPort
configV2rayIsTlsShowInfo="tls"
configV2rayTrojanPort="$(($RANDOM + 10000))"

configV2rayPath="${HOME}/v2ray"
configV2rayAccessLogFilePath="${HOME}/v2ray-access.log"
configV2rayErrorLogFilePath="${HOME}/v2ray-error.log"
configV2rayVmessImportLinkFile1Path="${configV2rayPath}/vmess_link1.json"
configV2rayVmessImportLinkFile2Path="${configV2rayPath}/vmess_link2.json"
configV2rayVlessImportLinkFile1Path="${configV2rayPath}/vless_link1.json"
configV2rayVlessImportLinkFile2Path="${configV2rayPath}/vless_link2.json"

configV2rayProtocol="vmess"
configV2rayWorkingMode=""
configV2rayWorkingNotChangeMode=""
configV2rayStreamSetting=""


configReadme=${HOME}/readme_trojan_v2ray.txt


function downloadAndUnzip(){
    if [ -z $1 ]; then
        green " ================================================== "
        green "The download file address is empty!"
        green " ================================================== "
        exit
    fi
    if [ -z $2 ]; then
        green " ================================================== "
        green "Destination path address is empty!"
        green " ================================================== "
        exit
    fi
    if [ -z $3 ]; then
        green " ================================================== "
        green "The filename of the downloaded file is empty!"
        green " ================================================== "
        exit
    fi

    mkdir -p ${configDownloadTempPath}

    if [[ $3 == *"tar.xz"* ]]; then
        green "====== Download and extract the tar file: $3 "
        wget -O ${configDownloadTempPath}/$3 $1
        tar xf ${configDownloadTempPath}/$3 -C ${configDownloadTempPath}
        mv ${configDownloadTempPath}/trojan/* $2
        rm -rf ${configDownloadTempPath}/trojan
    else
        green "====== Download and unzip the zip file: $3 "
        wget -O ${configDownloadTempPath}/$3 $1
        unzip -d $2 ${configDownloadTempPath}/$3
    fi

}

function getGithubLatestReleaseVersion(){
    # https://github.com/p4gefau1t/trojan-go/issues/63
    wget --no-check-certificate -qO- https://api.github.com/repos/$1/tags | grep 'name' | cut -d\" -f4 | head -1 | cut -b 2-
}

function getTrojanAndV2rayVersion(){
    # https://github.com/trojan-gfw/trojan/releases/download/v1.16.0/trojan-1.16.0-linux-amd64.tar.xz

    echo ""

    if [[ $1 == "trojan" ]] ; then
        versionTrojan=$(getGithubLatestReleaseVersion "trojan-gfw/trojan")
        downloadFilenameTrojan="trojan-${versionTrojan}-linux-amd64.tar.xz"
        echo "versionTrojan: ${versionTrojan}"
    fi

    if [[ $1 == "trojan-go" ]] ; then
        versionTrojanGo=$(getGithubLatestReleaseVersion "p4gefau1t/trojan-go")
        echo "versionTrojanGo: ${versionTrojanGo}"  
    fi

    if [[ $1 == "v2ray" ]] ; then
        # versionV2ray=$(getGithubLatestReleaseVersion "v2fly/v2ray-core")
        echo "versionV2ray: ${versionV2ray}"
    fi

    if [[ $1 == "xray" ]] ; then
        versionXray=$(getGithubLatestReleaseVersion "XTLS/Xray-core")
        echo "versionXray: ${versionXray}"
    fi

    if [[ $1 == "trojan-web" ]] ; then
        versionTrojanWeb=$(getGithubLatestReleaseVersion "Jrohy/trojan")
        echo "versionTrojanWeb: ${versionTrojanWeb}"
    fi

    if [[ $1 == "wgcf" ]] ; then
        versionWgcf=$(getGithubLatestReleaseVersion "ViRb3/wgcf")
        downloadFilenameWgcf="wgcf_${versionWgcf}_linux_amd64"
        echo "versionWgcf: ${versionWgcf}"
    fi

}








configNetworkRealIp=""
configSSLDomain=""



acmeSSLRegisterEmailInput=""
isDomainSSLGoogleEABKeyInput=""
isDomainSSLGoogleEABIdInput=""

function getHTTPSCertificateCheckEmail(){
    if [ -z $2 ]; then
        
        if [[ $1 == "email" ]]; then
            red "The input email address cannot be empty, please re-enter!"
            getHTTPSCertificateInputEmail
        elif [[ $1 == "googleEabKey" ]]; then
            red "Enter EAB key cannot be empty, please re-enter!"
            getHTTPSCertificateInputGoogleEABKey
        elif [[ $1 == "googleEabId" ]]; then
            red "Enter EAB Id cannot be empty, please re-enter!"
            getHTTPSCertificateInputGoogleEABId            
        fi
    fi
}
function getHTTPSCertificateInputEmail(){
    echo
    read -r -p "Please enter an email address to apply for a certificate:" acmeSSLRegisterEmailInput
    getHTTPSCertificateCheckEmail "email" "${acmeSSLRegisterEmailInput}"
}
function getHTTPSCertificateInputGoogleEABKey(){
    echo
    read -r -p "Please enter Google EAB key:" isDomainSSLGoogleEABKeyInput
    getHTTPSCertificateCheckEmail "googleEabKey" "${isDomainSSLGoogleEABKeyInput}"
}
function getHTTPSCertificateInputGoogleEABId(){
    echo
    read -r -p "Please enter Google EAB id:" isDomainSSLGoogleEABIdInput
    getHTTPSCertificateCheckEmail "googleEabId" "${isDomainSSLGoogleEABIdInput}"
}


acmeSSLDays="89"
acmeSSLServerName="letsencrypt"
acmeSSLDNSProvider="dns_cf"

configRanPath="${HOME}/ran"
configSSLAcmeScriptPath="${HOME}/.acme.sh"
configSSLCertPath="${configWebsiteFatherPath}/cert"

configSSLCertKeyFilename="private.key"
configSSLCertFullchainFilename="fullchain.cer"


function renewCertificationWithAcme(){

    # https://stackoverflow.com/questions/8880603/loop-through-an-array-of-strings-in-bash
    # https://stackoverflow.com/questions/9954680/how-to-store-directory-files-listing-into-an-array
    
    shopt -s nulllob
    renewDomainArray=("${configSSLAcmeScriptPath}"/*ecc*)

    COUNTER1=1

    if [ ${#renewDomainArray[@]} -ne 0 ]; then
        echo
        green " ================================================== "
        green "Detect whether the machine has applied for a domain name certificate or not to add a domain name certificate"
        yellow "reinstall trojan or v2ray after a new install or uninstall please select add instead of renew"
        echo
        green " 1. Add application for domain name certificate"
        green " 2. Renew the applied domain name certificate"
        green " 3. Delete the domain name certificate that has been applied for"
        echo
        read -r -p "Please choose whether to add a domain name certificate? By default, press Enter to add, please enter pure numbers:" isAcmeSSLAddNewInput
        isAcmeSSLAddNewInput=${isAcmeSSLAddNewInput:-1}
        if [[ "$isAcmeSSLAddNewInput" == "2" || "$isAcmeSSLAddNewInput" == "3" ]]; then

            echo
            green " ================================================== "
            green "Please select a domain name to renew or delete:"
            echo
            for renewDomainName in "${renewDomainArray[@]}"; do
                
                substr=${renewDomainName##*/}
                substr=${substr%_ecc*}
                renewDomainArrayFix[${COUNTER1}]="$substr"
                echo " ${COUNTER1}. Domain name: ${substr}"

                COUNTER1=$((COUNTER1 +1))
            done

            echo
            read -r -p "Please select a domain name? Please enter a pure number:" isRenewDomainSelectNumberInput
            isRenewDomainSelectNumberInput=${isRenewDomainSelectNumberInput:-99}
        
            if [[ "$isRenewDomainSelectNumberInput" == "99" ]]; then
                red "Incorrect input, please try again!"
                echo
                read -r -p "Please select a domain name? Please enter a pure number:" isRenewDomainSelectNumberInput
                isRenewDomainSelectNumberInput=${isRenewDomainSelectNumberInput:-99}

                if [[ "$isRenewDomainSelectNumberInput" == "99" ]]; then
                    red "Type error, exit!"
                    exit
                else
                    echo
                fi
            else
                echo
            fi

            configSSLRenewDomain=${renewDomainArrayFix[${isRenewDomainSelectNumberInput}]}


            if [[ -n $(${configSSLAcmeScriptPath}/acme.sh --list | grep ${configSSLRenewDomain}) ]]; then

                if [[ "$isAcmeSSLAddNewInput" == "2" ]]; then
                    ${configSSLAcmeScriptPath}/acme.sh --renew -d ${configSSLRenewDomain} --force --ecc
                    echo
                    green "The certificate for the domain ${configSSLRenewDomain} has been successfully renewed!"

                elif [[ "$isAcmeSSLAddNewInput" == "3" ]]; then
                    ${configSSLAcmeScriptPath}/acme.sh --revoke -d ${configSSLRenewDomain} --ecc
                    ${configSSLAcmeScriptPath}/acme.sh --remove -d ${configSSLRenewDomain} --ecc

                    rm -rf "${configSSLAcmeScriptPath}/${configSSLRenewDomain}_ecc"
                    echo
                    green "The certificate of the domain ${configSSLRenewDomain} has been deleted successfully!"
                    exit
                fi  
            else
                echo
                red "The certificate for the domain ${configSSLRenewDomain} does not exist!"
            fi

        else 
            getHTTPSCertificateStep1
        fi

    else
        getHTTPSCertificateStep1
    fi

}

function getHTTPSCertificateWithAcme(){

    # Apply for https certificate
	mkdir -p ${configSSLCertPath}
	mkdir -p ${configWebsitePath}
	curl https://get.acme.sh | sh


    echo
    green " ================================================== "
    green "Please select a certificate provider, the default is to apply for a certificate through Letsencrypt.org"
    green "If the certificate application fails, such as too many applications through Letsencrypt.org in one day, you can choose BuyPass.com or ZeroSSL.com to apply."
    green " 1 Letsencrypt.org "
    green " 2 BuyPass.com "
    green " 3 ZeroSSL.com "
    green " 4 Google Public CA "
    echo
    read -r -p "Please select a certificate provider? The default is to apply through Letsencrypt.org, please enter a pure number:" isDomainSSLFromLetInput
    isDomainSSLFromLetInput=${isDomainSSLFromLetInput:-1}
    
    if [[ "$isDomainSSLFromLetInput" == "2" ]]; then
        getHTTPSCertificateInputEmail
        acmeSSLDays="179"
        acmeSSLServerName="buypass"
        echo
        ${configSSLAcmeScriptPath}/acme.sh --register-account --accountemail ${acmeSSLRegisterEmailInput} --server buypass
        
    elif [[ "$isDomainSSLFromLetInput" == "3" ]]; then
        getHTTPSCertificateInputEmail
        acmeSSLServerName="zerossl"
        echo
        ${configSSLAcmeScriptPath}/acme.sh --register-account -m ${acmeSSLRegisterEmailInput} --server zerossl

    elif [[ "$isDomainSSLFromLetInput" == "4" ]]; then
        green " ================================================== "
        yellow "Please follow the link below to apply for google Public CA https://hostloc.com/thread-993780-1-1.html"
        yellow " For details, please refer to https://github.com/acmesh-official/acme.sh/wiki/Google-Public-CA"
        getHTTPSCertificateInputEmail
        acmeSSLServerName="google"
        getHTTPSCertificateInputGoogleEABKey
        getHTTPSCertificateInputGoogleEABId
        ${configSSLAcmeScriptPath}/acme.sh --register-account -m ${acmeSSLRegisterEmailInput} --server google --eab-kid ${isDomainSSLGoogleEABIdInput} --eab-hmac-key ${isDomainSSLGoogleEABKeyInput}    
    else
        acmeSSLServerName="letsencrypt"
        #${configSSLAcmeScriptPath}/acme.sh --issue -d ${configSSLDomain} --webroot ${configWebsitePath} --keylength ec-256 --days 89 --server letsencrypt
    fi


    echo
    green " ================================================== "
    green "Please select the acme.sh script to apply for the SSL certificate method: 1 http method, 2 dns method"
    green "The default is to press Enter directly for the http application method, otherwise it is the dns method"
    echo
    read -r -p "Please select the SSL certificate application method? The default is to use the http method to directly press Enter. Otherwise, the dns method is used to apply for a certificate, please enter [Y/n]:" isAcmeSSLRequestMethodInput
    isAcmeSSLRequestMethodInput=${isAcmeSSLRequestMethodInput:-Y}
    echo

    if [[ $isAcmeSSLRequestMethodInput == [Yy] ]]; then
        acmeSSLHttpWebrootMode=""

        if [[ -n "${configInstallNginxMode}" ]]; then
            acmeDefaultValue="3"
            acmeDefaultText="3. webroot and use ran as a temporary web server"
            acmeSSLHttpWebrootMode="webrootran"
        else
            acmeDefaultValue="1"
            acmeDefaultText="1. standalone mode"
            acmeSSLHttpWebrootMode="standalone"
        fi
        
        if [ -z "$1" ]; then
 
            green " ================================================== "
            green "Please select the HTTP certificate application method: the default is to enter directly as ${acmeDefaultText} "
            green " 1 standalone mode, suitable for no web server installed, if you have chosen not to install Nginx, please select this mode. Please make sure that port 80 is not occupied. Note: if port 80 is occupied after three months, the renewal will fail!"
            green " 2 webroot mode, suitable for already installed web server, such as Caddy Apache or Nginx, please make sure the web server is running on port 80"
            green " 3 webroot mode and use ran as a temporary web server, if you have chosen to install Nginx at the same time, please use this mode, you can renew normally"
            green "4 nginx mode is suitable for Nginx installed, please make sure Nginx is running"
            echo
            read -r -p "Please select the HTTP certificate application method? The default is ${acmeDefaultText}, please input pure numbers:" isAcmeSSLWebrootModeInput

            isAcmeSSLWebrootModeInput=${isAcmeSSLWebrootModeInput:-${acmeDefaultValue}}
            
            if [[ ${isAcmeSSLWebrootModeInput} == "1" ]]; then
                acmeSSLHttpWebrootMode="standalone"
            elif [[ ${isAcmeSSLWebrootModeInput} == "2" ]]; then
                acmeSSLHttpWebrootMode="webroot"
            elif [[ ${isAcmeSSLWebrootModeInput} == "4" ]]; then
                acmeSSLHttpWebrootMode="nginx"
            else
                acmeSSLHttpWebrootMode="webrootran"
            fi
        else
            if [[ $1 == "standalone" ]]; then
                acmeSSLHttpWebrootMode="standalone"
            elif [[ $1 == "webroot" ]]; then
                acmeSSLHttpWebrootMode="webroot"
            elif [[ $1 == "webrootran" ]] ; then
                acmeSSLHttpWebrootMode="webrootran"
            elif [[ $1 == "nginx" ]] ; then
                acmeSSLHttpWebrootMode="nginx"
            fi
        fi

        echo
        if [[ ${acmeSSLHttpWebrootMode} == "standalone" ]] ; then
            green "Start to apply for certificate acme.sh apply from ${acmeSSLServerName} through http standalone mode, please make sure port 80 is not occupied"
            
            echo
            ${configSSLAcmeScriptPath}/acme.sh --issue -d ${configSSLDomain} --standalone --keylength ec-256 --days ${acmeSSLDays} --server ${acmeSSLServerName}
        
        elif [[ ${acmeSSLHttpWebrootMode} == "webroot" ]] ; then
            green "Start to apply for certificate, acme.sh apply from ${acmeSSLServerName} through http webroot mode, please make sure web server such as nginx is running on port 80"
            
            echo
            read -r -p "Please enter the html website root directory path of the web server? For example /usr/share/nginx/html:" isDomainSSLNginxWebrootFolderInput
            echo "The root directory path of the website you entered is ${isDomainSSLNginxWebrootFolderInput}"

            if [ -z ${isDomainSSLNginxWebrootFolderInput} ]; then
                red "The html website root directory path of the entered web server cannot be empty. The website root directory will be set to ${configWebsitePath} by default. Please modify your web server configuration before applying for a certificate!"
                
            else
                configWebsitePath="${isDomainSSLNginxWebrootFolderInput}"
            fi
            
            echo
            ${configSSLAcmeScriptPath}/acme.sh --issue -d ${configSSLDomain} --webroot ${configWebsitePath} --keylength ec-256 --days ${acmeSSLDays} --server ${acmeSSLServerName}
        
        elif [[ ${acmeSSLHttpWebrootMode} == "nginx" ]] ; then
            green "Start to apply for certificate, acme.sh apply from ${acmeSSLServerName} through http nginx mode, please make sure web server nginx is running"
            
            echo
            ${configSSLAcmeScriptPath}/acme.sh --issue -d ${configSSLDomain} --nginx --keylength ec-256 --days ${acmeSSLDays} --server ${acmeSSLServerName}

        elif [[ ${acmeSSLHttpWebrootMode} == "webrootran" ]] ; then

            # https://github.com/m3ng9i/ran/issues/10

            ranDownloadUrl="https://github.com/m3ng9i/ran/releases/download/v0.1.6/ran_linux_amd64.zip"
            ranDownloadFileName="ran_linux_amd64"
            
            if [[ "${osArchitecture}" == "arm64" || "${osArchitecture}" == "arm" ]]; then
                ranDownloadUrl="https://github.com/m3ng9i/ran/releases/download/v0.1.6/ran_linux_arm64.zip"
                ranDownloadFileName="ran_linux_arm64"
            fi


            mkdir -p ${configRanPath}
            
            if [[ -f "${configRanPath}/${ranDownloadFileName}" ]]; then
                green "Detected that ran has been downloaded, ready to start the ran temporary web server"
            else
                green "Start downloading ran as a temporary web server"
                downloadAndUnzip "${ranDownloadUrl}" "${configRanPath}" "${ranDownloadFileName}" 
                chmod +x "${configRanPath}/${ranDownloadFileName}"
            fi

            echo "nohup ${configRanPath}/${ranDownloadFileName} -l=false -g=false -sa=true -p=80 -r=${configWebsitePath} >/dev/null 2>&1 &"
            nohup ${configRanPath}/${ranDownloadFileName} -l=false -g=false -sa=true -p=80 -r=${configWebsitePath} >/dev/null 2>&1 &
            echo
            
            green "Start to apply for certificate, acme.sh apply from ${acmeSSLServerName} through http webroot mode, and use ran as temporary web server"
            echo
            ${configSSLAcmeScriptPath}/acme.sh --issue -d ${configSSLDomain} --webroot ${configWebsitePath} --keylength ec-256 --days ${acmeSSLDays} --server ${acmeSSLServerName}

            sleep 4
            ps -C ${ranDownloadFileName} -o pid= | xargs -I {} kill {}
        fi

    else
        green "Start to apply for certificate, acme.sh apply through dns mode"

        echo
        green "Please select DNS provider DNS provider: 1 CloudFlare, 2 AliYun, 3 DNSPod(Tencent), 4 GoDaddy "
        red "Note that CloudFlare no longer supports using API to apply for DNS certificates for some free domain names such as .tk .cf"
        echo
        read -r -p "Please select a DNS provider? The default is to enter 1. CloudFlare, please enter a pure number:" isAcmeSSLDNSProviderInput
        isAcmeSSLDNSProviderInput=${isAcmeSSLDNSProviderInput:-1}    

        
        if [ "$isAcmeSSLDNSProviderInput" == "2" ]; then
            read -r -p "Please Input Ali Key: " Ali_Key
            export Ali_Key="${Ali_Key}"
            read -r -p "Please Input Ali Secret: " Ali_Secret
            export Ali_Secret="${Ali_Secret}"
            acmeSSLDNSProvider="dns_ali"

        elif [ "$isAcmeSSLDNSProviderInput" == "3" ]; then
            read -r -p "Please Input DNSPod API ID: " DP_Id
            export DP_Id="${DP_Id}"
            read -r -p "Please Input DNSPod API Key: " DP_Key
            export DP_Key="${DP_Key}"
            acmeSSLDNSProvider="dns_dp"

        elif [ "$isAcmeSSLDNSProviderInput" == "4" ]; then
            read -r -p "Please Input GoDaddy API Key: " gd_Key
            export GD_Key="${gd_Key}"
            read -r -p "Please Input GoDaddy API Secret: " gd_Secret
            export GD_Secret="${gd_Secret}"
            acmeSSLDNSProvider="dns_gd"

        else
            read -r -p "Please Input CloudFlare Email: " cf_email
            export CF_Email="${cf_email}"
            read -r -p "Please Input CloudFlare Global API Key: " cf_key
            export CF_Key="${cf_key}"
            acmeSSLDNSProvider="dns_cf"
        fi
        
        echo
        ${configSSLAcmeScriptPath}/acme.sh --issue -d "${configSSLDomain}" --dns ${acmeSSLDNSProvider} --force --keylength ec-256 --server ${acmeSSLServerName} --debug 
        
    fi

    echo
    if [[ ${isAcmeSSLWebrootModeInput} == "1" ]]; then
        ${configSSLAcmeScriptPath}/acme.sh --installcert --ecc -d ${configSSLDomain} \
        --key-file ${configSSLCertPath}/${configSSLCertKeyFilename} \
        --fullchain-file ${configSSLCertPath}/${configSSLCertFullchainFilename} 
    else
        ${configSSLAcmeScriptPath}/acme.sh --installcert --ecc -d ${configSSLDomain} \
        --key-file ${configSSLCertPath}/${configSSLCertKeyFilename} \
        --fullchain-file ${configSSLCertPath}/${configSSLCertFullchainFilename} \
        --reloadcmd "systemctl restart nginx.service"
    fi
    green " ================================================== "
}




function compareRealIpWithLocalIp(){
    echo
    green "Whether to check whether the IP pointed to by the domain name is correct and directly press Enter to check by default"
    red "If the IP pointed to by the domain name is not the local IP, or the CDN has been opened, it is inconvenient to close or the VPS only has IPv6, you can choose whether to not detect it"
    read -r -p "Does the detection domain name point to the correct IP? Please enter [Y/n]:" isDomainValidInput
    isDomainValidInput=${isDomainValidInput:-Y}

    if [[ $isDomainValidInput == [Yy] ]]; then
        if [[ -n "$1" ]]; then
            configNetworkRealIp=$(ping $1 -c 1 | sed '1{s/[^(]*(//;s/).*//;q}')
            # https://unix.stackexchange.com/questions/22615/how-can-i-get-my-external-ip-address-in-a-shell-script
            configNetworkLocalIp1="$(curl http://whatismyip.akamai.com/)"
            configNetworkLocalIp2="$(curl https://checkip.amazonaws.com/)"
            #configNetworkLocalIp3="$(curl https://ipv4.icanhazip.com/)"
            #configNetworkLocalIp4="$(curl https://v4.ident.me/)"
            #configNetworkLocalIp5="$(curl https://api.ip.sb/ip)"
            #configNetworkLocalIp6="$(curl https://ipinfo.io/ip)"
            
            
            #configNetworkLocalIPv61="$(curl https://ipv6.icanhazip.com/)"
            #configNetworkLocalIPv62="$(curl https://v6.ident.me/)"


            green " ================================================== "
            green "The domain name resolution address is ${configNetworkRealIp}, the IP of this VPS is ${configNetworkLocalIp1} "

            echo
            if [[ ${configNetworkRealIp} == "${configNetworkLocalIp1}" || ${configNetworkRealIp} == "${configNetworkLocalIp2}" ]] ; then

                green "The IP address of the domain name resolution is normal!"
                green " ================================================== "
                true
            else
                red "The domain name resolution address is inconsistent with the IP address of this VPS!"
                red "This installation failed, please ensure that the domain name resolution is normal, please check whether the domain name and DNS are valid!"
                green " ================================================== "
                false
            fi
        else
            green " ================================================== "        
            red "The domain name was entered incorrectly!"
            green " ================================================== "        
            false
        fi
        
    else
        green " ================================================== "
        green "Do not check whether the domain name resolution is correct!"
        green " ================================================== "
        true
    fi
}


function getHTTPSCertificateStep1(){
    
    echo
    green " ================================================== "
    yellow "Please enter the domain name that resolves to this VPS, such as www.xxx.com: (In this step, please close the CDN and install it after nginx to avoid the failure to apply for a certificate due to port 80 occupation)"
    read -r -p "Please enter the domain name resolved to this VPS:" configSSLDomain

    if compareRealIpWithLocalIp "${configSSLDomain}" ; then
        echo
        green " =================================================="
        green "Do you want to apply for a certificate? By default, press Enter to apply for a certificate. If you are installing for the second time or you have an existing certificate, you can choose No"
        green "If there is already an SSL certificate file, please put it in the following path"
        red " ${configSSLDomain} domain name certificate content file path ${configSSLCertPath}/${configSSLCertFullchainFilename} "
        red " ${configSSLDomain} domain name certificate private key file path ${configSSLCertPath}/${configSSLCertKeyFilename} "
        echo

        read -r -p "Do you want to apply for a certificate? By default, press Enter to automatically apply for a certificate, please enter [Y/n]:" isDomainSSLRequestInput
        isDomainSSLRequestInput=${isDomainSSLRequestInput:-Y}

        if [[ $isDomainSSLRequestInput == [Yy] ]]; then
            getHTTPSCertificateWithAcme ""
        else
            green " =================================================="
            green "Do not apply for a domain name certificate, please put the certificate in the following directory, or modify the trojan or v2ray configuration yourself!"
            green " ${configSSLDomain} domain name certificate content file path ${configSSLCertPath}/${configSSLCertFullchainFilename} "
            green " ${configSSLDomain} domain name certificate private key file path ${configSSLCertPath}/${configSSLCertKeyFilename} "
            green " =================================================="
        fi
    else
        exit
    fi

}














function stopServiceNginx(){
    serviceNginxStatus=$(ps -aux | grep "nginx: worker" | grep -v "grep")
    if [[ -n "$serviceNginxStatus" ]]; then
        ${sudoCmd} systemctl stop nginx.service
    fi
}

function stopServiceV2ray(){
    if [[ -f "${osSystemMdPath}v2ray.service" ]] || [[ -f "/etc/systemd/system/v2ray.service" ]] || [[ -f "/lib/systemd/system/v2ray.service" ]] ; then
        ${sudoCmd} systemctl stop v2ray.service
    fi
}


function installWebServerNginx(){

    echo
    green " ================================================== "
    yellow "Start installing web server nginx!"
    green " ================================================== "
    echo

    if test -s ${nginxConfigPath}; then
        green " ================================================== "
        red "Nginx already exists, exit installation!"
        green " ================================================== "
        exit
    fi

    stopServiceV2ray

	wwwUsername="www-data"
	isHaveWwwUser=$(cat /etc/passwd|cut -d ":" -f 1|grep ^www-data$)
	if [ "${isHaveWwwUser}" != "${wwwUsername}" ]; then
		${sudoCmd} groupadd ${wwwUsername}
		${sudoCmd} useradd -s /usr/sbin/nologin -g ${wwwUsername} ${wwwUsername} --no-create-home         
	fi

    ${sudoCmd} chown -R ${wwwUsername}:${wwwUsername} ${configWebsiteFatherPath}
    ${sudoCmd} chmod -R 774 ${configWebsiteFatherPath}

    if [ "$osRelease" == "centos" ]; then
        ${osSystemPackage} install -y nginx-mod-stream
    else
        echo
        groupadd -r -g 4 adm

        apt autoremove -y
        apt-get remove --purge -y nginx-common
        apt-get remove --purge -y nginx-core
        apt-get remove --purge -y libnginx-mod-stream
        apt-get remove --purge -y libnginx-mod-http-xslt-filter libnginx-mod-http-geoip2 libnginx-mod-stream-geoip2 libnginx-mod-mail libnginx-mod-http-image-filter

        apt autoremove -y --purge nginx nginx-common nginx-core
        apt-get remove --purge -y nginx nginx-full nginx-common nginx-core

        #${osSystemPackage} install -y libnginx-mod-stream
    fi

    ${osSystemPackage} install -y nginx
    ${sudoCmd} systemctl enable nginx.service
    ${sudoCmd} systemctl stop nginx.service

    # Solve the nginx warning error Failed to parse PID from file /run/nginx.pid: Invalid argument
    # https://www.kancloud.cn/tinywan/nginx_tutorial/753832
    
    mkdir -p /etc/systemd/system/nginx.service.d
    printf "[Service]\nExecStartPost=/bin/sleep 0.1\n" > /etc/systemd/system/nginx.service.d/override.conf
    
    ${sudoCmd} systemctl daemon-reload
    



    nginxConfigServerHttpInput=""
    nginxConfigStreamConfigInput=""
    nginxConfigNginxModuleInput=""

    if [[ "${configInstallNginxMode}" == "noSSL" ]]; then
        if [[ ${configV2rayWorkingNotChangeMode} == "true" ]]; then
            inputV2rayStreamSettings
        fi

        if [[ "${configV2rayStreamSetting}" == "grpc" || "${configV2rayStreamSetting}" == "wsgrpc" ]]; then
            read -r -d '' nginxConfigServerHttpInput << EOM
    server {
        listen       80;
        server_name  $configSSLDomain;
        root $configWebsitePath;
        index index.php index.html index.htm;

        location /$configV2rayWebSocketPath {
            proxy_pass http://127.0.0.1:$configV2rayPort;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host \$http_host;

            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }

        location /$configV2rayGRPCServiceName {
            grpc_pass grpc://127.0.0.1:$configV2rayGRPCPort;
            grpc_connect_timeout 60s;
            grpc_read_timeout 720m;
            grpc_send_timeout 720m;
            grpc_set_header X-Real-IP \$remote_addr;
            grpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }  
    }

EOM

        else
            read -r -d '' nginxConfigServerHttpInput << EOM
    server {
        listen       80;
        server_name  $configSSLDomain;
        root $configWebsitePath;
        index index.php index.html index.htm;

        location /$configV2rayWebSocketPath {
            proxy_pass http://127.0.0.1:$configV2rayPort;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host \$http_host;

            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }
    }

EOM

        fi



    elif [[ "${configInstallNginxMode}" == "v2raySSL" ]]; then
        inputV2rayStreamSettings

        read -r -d '' nginxConfigServerHttpInput << EOM
    server {
        listen 443 ssl http2;
        listen [::]:443 http2;
        server_name  $configSSLDomain;

        ssl_certificate       ${configSSLCertPath}/$configSSLCertFullchainFilename;
        ssl_certificate_key   ${configSSLCertPath}/$configSSLCertKeyFilename;
        ssl_protocols         TLSv1.2 TLSv1.3;
        ssl_ciphers           TLS-AES-256-GCM-SHA384:TLS-CHACHA20-POLY1305-SHA256:TLS-AES-128-GCM-SHA256:TLS-AES-128-CCM-8-SHA256:TLS-AES-128-CCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256;

        # Config for 0-RTT in TLSv1.3
        ssl_early_data on;
        ssl_stapling on;
        ssl_stapling_verify on;
        add_header Strict-Transport-Security "max-age=31536000";
        
        root $configWebsitePath;
        index index.php index.html index.htm;

        location /$configV2rayWebSocketPath {
            proxy_pass http://127.0.0.1:$configV2rayPort;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host \$http_host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }

        location /$configV2rayGRPCServiceName {
            grpc_pass grpc://127.0.0.1:$configV2rayGRPCPort;
            grpc_connect_timeout 60s;
            grpc_read_timeout 720m;
            grpc_send_timeout 720m;
            grpc_set_header X-Real-IP \$remote_addr;
            grpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }
    }

    server {
        listen 80;
        listen [::]:80;
        server_name  $configSSLDomain;
        return 301 https://$configSSLDomain\$request_uri;
    }

EOM

    elif [[ "${configInstallNginxMode}" == "sni" ]]; then

        if [ "$osRelease" == "centos" ]; then
        read -r -d '' nginxConfigNginxModuleInput << EOM
load_module /usr/lib64/nginx/modules/ngx_stream_module.so;
EOM
        else
        read -r -d '' nginxConfigNginxModuleInput << EOM
include /etc/nginx/modules-enabled/*.conf;
# load_module /usr/lib/nginx/modules/ngx_stream_module.so;
EOM
        fi



        nginxConfigStreamFakeWebsiteDomainInput=""

        nginxConfigStreamOwnWebsiteInput=""
        nginxConfigStreamOwnWebsiteMapInput=""

        if [[ "${isNginxSNIModeInput}" == "4" || "${isNginxSNIModeInput}" == "5" || "${isNginxSNIModeInput}" == "6" ]]; then

            read -r -d '' nginxConfigStreamOwnWebsiteInput << EOM
    server {
        listen 8000 ssl http2;
        listen [::]:8000 http2;
        server_name  $configNginxSNIDomainWebsite;

        ssl_certificate       ${configNginxSNIDomainWebsiteCertPath}/$configSSLCertFullchainFilename;
        ssl_certificate_key   ${configNginxSNIDomainWebsiteCertPath}/$configSSLCertKeyFilename;
        ssl_protocols         TLSv1.2 TLSv1.3;
        ssl_ciphers           TLS-AES-256-GCM-SHA384:TLS-CHACHA20-POLY1305-SHA256:TLS-AES-128-GCM-SHA256:TLS-AES-128-CCM-8-SHA256:TLS-AES-128-CCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256;

        # Config for 0-RTT in TLSv1.3
        ssl_early_data on;
        ssl_stapling on;
        ssl_stapling_verify on;
        add_header Strict-Transport-Security "max-age=31536000";
        
        root $configWebsitePath;
        index index.php index.html index.htm;

    }

    server {
        listen 80;
        listen [::]:80;
        server_name  $configNginxSNIDomainWebsite;
        return 301 https://$configNginxSNIDomainWebsite\$request_uri;
    }
EOM

            read -r -d '' nginxConfigStreamOwnWebsiteMapInput << EOM
        ${configNginxSNIDomainWebsite} web;
EOM
        fi


        nginxConfigStreamTrojanMapInput=""
        nginxConfigStreamTrojanUpstreamInput=""

        if [[ "${isNginxSNIModeInput}" == "1" || "${isNginxSNIModeInput}" == "2" || "${isNginxSNIModeInput}" == "4" || "${isNginxSNIModeInput}" == "5" ]]; then
            
            nginxConfigStreamFakeWebsiteDomainInput="${configNginxSNIDomainTrojan}"

            read -r -d '' nginxConfigStreamTrojanMapInput << EOM
        ${configNginxSNIDomainTrojan} trojan;
EOM

            read -r -d '' nginxConfigStreamTrojanUpstreamInput << EOM
    upstream trojan {
        server 127.0.0.1:$configV2rayTrojanPort;
    }
EOM
        fi


        nginxConfigStreamV2rayMapInput=""
        nginxConfigStreamV2rayUpstreamInput=""

        if [[ "${isNginxSNIModeInput}" == "1" || "${isNginxSNIModeInput}" == "3" || "${isNginxSNIModeInput}" == "4" || "${isNginxSNIModeInput}" == "6" ]]; then

            nginxConfigStreamFakeWebsiteDomainInput="${nginxConfigStreamFakeWebsiteDomainInput} ${configNginxSNIDomainV2ray}"

            read -r -d '' nginxConfigStreamV2rayMapInput << EOM
        ${configNginxSNIDomainV2ray} v2ray;
EOM

            read -r -d '' nginxConfigStreamV2rayUpstreamInput << EOM
    upstream v2ray {
        server 127.0.0.1:$configV2rayPort;
    }
EOM
        fi


        read -r -d '' nginxConfigServerHttpInput << EOM
    server {
        listen       80;
        server_name  $nginxConfigStreamFakeWebsiteDomainInput;
        root $configWebsitePath;
        index index.php index.html index.htm;

    }

    ${nginxConfigStreamOwnWebsiteInput}

EOM


        read -r -d '' nginxConfigStreamConfigInput << EOM
stream {
    map \$ssl_preread_server_name \$filtered_sni_name {
        ${nginxConfigStreamOwnWebsiteMapInput}
        ${nginxConfigStreamTrojanMapInput}
        ${nginxConfigStreamV2rayMapInput}
    }
    
    ${nginxConfigStreamTrojanUpstreamInput}

    ${nginxConfigStreamV2rayUpstreamInput}

    upstream web {
        server 127.0.0.1:8000;
    }

    server {
        listen 443;
        listen [::]:443;
        resolver 8.8.8.8;
        ssl_preread on;
        proxy_pass \$filtered_sni_name;
    }
}

EOM

    elif [[ "${configInstallNginxMode}" == "trojanWeb" ]]; then

        read -r -d '' nginxConfigServerHttpInput << EOM
    server {
        listen       80;
        server_name  $configSSLDomain;
        root $configWebsitePath;
        index index.php index.html index.htm;

        location /$configTrojanWebNginxPath {
            proxy_pass http://127.0.0.1:$configTrojanWebPort/;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Host \$http_host;
        }

        location ~* ^/(static|common|auth|trojan)/ {
            proxy_pass  http://127.0.0.1:$configTrojanWebPort;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host \$http_host;
        }

        # http redirect to https
        if ( \$remote_addr != 127.0.0.1 ){
            rewrite ^/(.*)$ https://$configSSLDomain/\$1 redirect;
        }
    }

EOM

    else

        echo

    fi


        cat > "${nginxConfigPath}" <<-EOF

${nginxConfigNginxModuleInput}

user  ${wwwUsername} ${wwwUsername};
worker_processes  1;
error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}


${nginxConfigStreamConfigInput}


http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] '
                      '"\$request" \$status \$body_bytes_sent  '
                      '"\$http_referer" "\$http_user_agent" "\$http_x_forwarded_for"';
    access_log  $nginxAccessLogFilePath  main;
    error_log $nginxErrorLogFilePath;

    sendfile        on;
    #tcp_nopush     on;
    keepalive_timeout  120;
    client_max_body_size 20m;
    gzip  on;


    ${nginxConfigServerHttpInput}

}


EOF




    # Download the fake site and set the fake site
    rm -rf ${configWebsitePath}/*
    mkdir -p ${configWebsiteDownloadPath}

    downloadAndUnzip "https://github.com/jinwyp/one_click_script/raw/master/download/website2.zip" "${configWebsitePath}" "website2.zip"


    if [ "${configInstallNginxMode}" != "trojanWeb" ] ; then
        wget -P "${configWebsiteDownloadPath}" "https://github.com/jinwyp/one_click_script/raw/master/download/trojan-mac.zip"
        wget -P "${configWebsiteDownloadPath}" "https://github.com/jinwyp/one_click_script/raw/master/download/v2ray-windows.zip" 
        wget -P "${configWebsiteDownloadPath}" "https://github.com/jinwyp/one_click_script/raw/master/download/v2ray-mac.zip"
    fi


    # downloadAndUnzip "https://github.com/jinwyp/one_click_script/raw/master/download/trojan_client_all.zip" "${configWebsiteDownloadPath}" "trojan_client_all.zip"
    # downloadAndUnzip "https://github.com/jinwyp/one_click_script/raw/master/download/trojan-qt5.zip" "${configWebsiteDownloadPath}" "trojan-qt5.zip"
    # downloadAndUnzip "https://github.com/jinwyp/one_click_script/raw/master/download/v2ray_client_all.zip" "${configWebsiteDownloadPath}" "v2ray_client_all.zip"

    #wget -P "${configWebsiteDownloadPath}" "https://github.com/jinwyp/one_click_script/raw/master/download/v2ray-android.zip"

    ${sudoCmd} chown -R ${wwwUsername}:${wwwUsername} ${configWebsiteFatherPath}
    ${sudoCmd} chmod -R 774 ${configWebsiteFatherPath}

    ${sudoCmd} systemctl start nginx.service

    green " ================================================== "
    green "Web server nginx installed successfully!!"
    green "Pretend the site to be http://${configSSLDomain}"

	if [[ "${configInstallNginxMode}" == "trojanWeb" ]] ; then
	    yellow " Trojan-web ${versionTrojanWeb} visual management panel address http://${configSSLDomain}/${configTrojanWebNginxPath} "
	    green "Trojan-web visual management panel executable file path ${configTrojanWebPath}/trojan-web"
        green " Trojan-web stop command: systemctl stop trojan-web.service start command: systemctl start trojan-web.service restart command: systemctl restart trojan-web.service"
	    green "Trojan server-side executable path /usr/bin/trojan/trojan"
	    green " Trojan server side configuration path /usr/local/etc/trojan/config.json "
	    green "Trojan stop command: systemctl stop trojan.service start command: systemctl start trojan.service restart command: systemctl restart trojan.service"
	fi

    green "The static html content of the disguised site is placed in the directory ${configWebsitePath}, and the content of the website can be replaced by yourself!"
	red "nginx configuration path ${nginxConfigPath} "
	green "nginx access log ${nginxAccessLogFilePath} "
	green "nginx error log ${nginxErrorLogFilePath}"
    green " nginx view log command: journalctl -n 50 -u nginx.service"
	green " nginx start command: systemctl start nginx.service stop command: systemctl stop nginx.service restart command: systemctl restart nginx.service"
	green " nginx check running status command: systemctl status nginx.service "

    green " ================================================== "

    cat >> ${configReadme} <<-EOF

Web server nginx installed successfully! The fake site is ${configSSLDomain}   
The static html content of the fake site is placed in the directory ${configWebsitePath}, and the content of the website can be replaced by itself.
nginx configuration path ${nginxConfigPath}
nginx access log ${nginxAccessLogFilePath}
nginx error log ${nginxErrorLogFilePath}

nginx view log command: journalctl -n 50 -u nginx.service

nginx start command: systemctl start nginx.service  
nginx stop command: systemctl stop nginx.service  
nginx restart command: systemctl restart nginx.service
nginx check running status command: systemctl status nginx.service


EOF

	if [[ "${configInstallNginxMode}" == "trojanWeb" ]] ; then
        cat >> ${configReadme} <<-EOF

Installed Trojan-web ${versionTrojanWeb} visual admin panel
Access address http://${configSSLDomain}/${configTrojanWebNginxPath}
Trojan-web stop command: systemctl stop trojan-web.service  
Trojan-web start command: systemctl start trojan-web.service  
Trojan-web restart command: systemctl restart trojan-web.service

Trojan server-side configuration path /usr/local/etc/trojan/config.json
Trojan stop command: systemctl stop trojan.service
Trojan start command: systemctl start trojan.service
Trojan restart command: systemctl restart trojan.service
Trojan check running status command: systemctl status trojan.service

EOF
	fi

}

function removeNginx(){

    echo
    read -p "Are you sure to uninstall Nginx? Press Enter to uninstall by default, please enter [Y/n]:" isRemoveNginxServerInput
    isRemoveNginxServerInput=${isRemoveNginxServerInput:-Y}

    if [[ "${isRemoveNginxServerInput}" == [Yy] ]]; then

        echo
        if [[ -f "${nginxConfigPath}" ]]; then
            green " ================================================== "
            red "preparing to uninstall installed nginx"
            green " ================================================== "
            echo

            ${sudoCmd} systemctl stop nginx.service
            ${sudoCmd} systemctl disable nginx.service

            if [ "$osRelease" == "centos" ]; then
                yum remove -y nginx-mod-stream
                yum remove -y nginx
            else
                apt autoremove -y
                apt-get remove --purge -y nginx-common
                apt-get remove --purge -y nginx-core
                apt-get remove --purge -y libnginx-mod-stream
                apt-get remove --purge -y libnginx-mod-http-xslt-filter libnginx-mod-http-geoip2 libnginx-mod-stream-geoip2 libnginx-mod-mail libnginx-mod-http-image-filter

                apt autoremove -y --purge nginx nginx-common nginx-core
                apt-get remove --purge -y nginx nginx-full nginx-common nginx-core
            fi


            rm -f ${nginxAccessLogFilePath}
            rm -f ${nginxErrorLogFilePath}
            rm -f ${nginxConfigPath}

            rm -f ${configReadme}
            rm -rf "/etc/nginx"
            
            rm -rf ${configDownloadTempPath}

            echo
            read -p "Whether to delete the certificate and uninstall the acme.sh certificate application tool, because the number of times to apply for a certificate in one day is limited, it is recommended not to delete the certificate by default, please enter [y/N]:" isDomainSSLRemoveInput
            isDomainSSLRemoveInput=${isDomainSSLRemoveInput:-n}

            
            if [[ $isDomainSSLRemoveInput == [Yy] ]]; then
                rm -rf ${configWebsiteFatherPath}
                ${sudoCmd} bash ${configSSLAcmeScriptPath}/acme.sh --uninstall
                
                echo
                green " ================================================== "
                green "Nginx uninstallation completed, SSL certificate files have been removed!"
                
            else
                rm -rf ${configWebsitePath}
                echo
                green " ================================================== "
                green "Nginx uninstallation completed, the SSL certificate file has been preserved to ${configSSLCertPath} "
            fi

            green " ================================================== "
        else
            red "The system does not have nginx installed, exit to uninstall"
        fi
        echo

    fi    
}






























configNginxSNIDomainWebsite=""
configNginxSNIDomainV2ray=""
configNginxSNIDomainTrojan=""

configSSLCertPath="${configWebsiteFatherPath}/cert"
configNginxSNIDomainTrojanCertPath="${configWebsiteFatherPath}/cert/nginxsni/trojan"
configNginxSNIDomainV2rayCertPath="${configWebsiteFatherPath}/cert/nginxsni/v2ray"
configNginxSNIDomainWebsiteCertPath="${configWebsiteFatherPath}/cert/nginxsni/web"

function checkNginxSNIDomain(){

    if compareRealIpWithLocalIp "$2" ; then

        if [ "$1" = "trojan" ]; then
            configNginxSNIDomainTrojan=$2
            configSSLCertPath="${configNginxSNIDomainTrojanCertPath}"

        elif [ "$1" = "v2ray" ]; then
            configNginxSNIDomainV2ray=$2
            configSSLCertPath="${configNginxSNIDomainV2rayCertPath}"

        elif [ "$1" = "website" ]; then
            configNginxSNIDomainWebsite=$2
            configSSLCertPath="${configNginxSNIDomainWebsiteCertPath}"
        fi
        
        configSSLDomain="$2"
        mkdir -p ${configSSLCertPath}

        echo
        green " =================================================="
        green "Do you want to apply for a certificate? By default, press Enter to apply for a certificate. If you are installing for the second time or you have an existing certificate, you can choose No"
        green "If there is already an SSL certificate file, please put it in the following path"
        red " ${configSSLDomain} domain name certificate content file path ${configSSLCertPath}/${configSSLCertFullchainFilename} "
        red " ${configSSLDomain} domain name certificate private key file path ${configSSLCertPath}/${configSSLCertKeyFilename} "
        echo

        read -p "Do you want to apply for a certificate? By default, press Enter to automatically apply for a certificate, please enter [Y/n]:" isDomainSSLRequestInput
        isDomainSSLRequestInput=${isDomainSSLRequestInput:-Y}

        if [[ $isDomainSSLRequestInput == [Yy] ]]; then
            getHTTPSCertificateWithAcme ""
        else
            green " =================================================="
            green "Do not apply for a domain name certificate, please put the certificate in the following directory, or modify the trojan or v2ray configuration yourself!"
            green " ${configSSLDomain} domain name certificate content file path ${configSSLCertPath}/${configSSLCertFullchainFilename} "
            green " ${configSSLDomain} domain name certificate private key file path ${configSSLCertPath}/${configSSLCertKeyFilename} "
            green " =================================================="
        fi
    else
        inputNginxSNIDomain $1
    fi

}

function inputNginxSNIDomain(){
    echo
    green " ================================================== "

    if [ "$1" = "trojan" ]; then
        yellow "Please enter the domain name resolved to this VPS for use by Trojan, such as www.xxx.com: (Please close the CDN and install it in this step)"
        read -p "Please enter the domain name resolved to this VPS:" configNginxSNIDomainDefault
        
    elif [ "$1" = "v2ray" ]; then
        yellow "Please enter the domain name resolved to this VPS for use by V2ray, such as www.xxx.com: (Please close the CDN and install it in this step)"
        read -p "Please enter the domain name resolved to this VPS:" configNginxSNIDomainDefault
        
    elif [ "$1" = "website" ]; then
        yellow "Please enter the domain name resolved to this VPS for use by existing websites, such as www.xxx.com: (Please close the CDN and install it in this step)"
        read -p "Please enter the domain name resolved to this VPS:" configNginxSNIDomainDefault

    fi

    checkNginxSNIDomain $1 ${configNginxSNIDomainDefault}
    
}

function inputXraySystemdServiceName(){

    if [ "$1" = "v2ray_nginxOptional" ]; then
        echo
        green " ================================================== "
        yellow "Please enter a custom V2ray or Xray Systemd service name suffix, the default is empty"
        green "The default is to enter directly without entering characters, that is, v2ray.service or xray.service"
        green "The characters entered will be suffixed eg v2ray-xxx.service or xray-xxx.service"
        green "This feature is used to install multiple v2ray/xray on one VPS"
        echo
        read -p "Please enter a custom Xray service name suffix, the default is empty:" configXraySystemdServiceNameSuffix
        configXraySystemdServiceNameSuffix=${configXraySystemdServiceNameSuffix:-""}

        if [ -n "${configXraySystemdServiceNameSuffix}" ]; then
            promptInfoXrayNameServiceName="-${configXraySystemdServiceNameSuffix}"
            configSSLCertPath="${configSSLCertPath}/xray_${configXraySystemdServiceNameSuffix}"
        fi
        echo
    fi

}

function installTrojanV2rayWithNginx(){

    stopServiceNginx
    testLinuxPortUsage
    installPackage

    echo
    if [ "$1" = "v2ray" ]; then
        read -p "Do you want to install directly using the IP of this VPS without applying for a domain name certificate? By default, press Enter to not apply for a certificate, please enter [Y/n]:" isDomainIPRequestInput
        isDomainIPRequestInput=${isDomainIPRequestInput:-Y}

        if [[ $isDomainIPRequestInput == [Yy] ]]; then
            echo
            read -p "Please enter the IP of this VPS or resolve to the domain name of this VPS:" configSSLDomain
            installV2ray
            exit
        fi

    elif [ "$1" = "nginxSNI_trojan_v2ray" ]; then
        green " ================================================== "
        yellow "Please select the installation mode of Nginx SNI + Trojan + V2ray, the default is 1"
        echo
        green " 1. Nginx + Trojan + V2ray + Fake website"
        green " 2. Nginx + Trojan + Fake website"
        green " 3. Nginx + V2ray + Fake Website"
        green " 4. Nginx + Trojan + V2ray + existing website coexist"
        green " 5. Nginx + Trojan + existing website coexist"
        green " 6. Nginx + V2ray + existing website coexist"

        echo 
        read -p "Please select the installation mode of Nginx SNI directly press Enter to select 1 by default, please enter pure numbers:" isNginxSNIModeInput
        isNginxSNIModeInput=${isNginxSNIModeInput:-1}

        if [[ "${isNginxSNIModeInput}" == "1" ]]; then
            inputNginxSNIDomain "trojan"
            inputNginxSNIDomain "v2ray"
            

            installWebServerNginx
            installTrojanServer
            installV2ray

        elif [[ "${isNginxSNIModeInput}" == "2" ]]; then
            inputNginxSNIDomain "trojan"

            installWebServerNginx
            installTrojanServer

        elif [[ "${isNginxSNIModeInput}" == "3" ]]; then
            inputNginxSNIDomain "v2ray"

            installWebServerNginx
            installV2ray

        elif [[ "${isNginxSNIModeInput}" == "4" ]]; then
            inputNginxSNIDomain "trojan"
            inputNginxSNIDomain "v2ray"
            inputNginxSNIDomain "website"

            installWebServerNginx
            installTrojanServer
            installV2ray

        elif [[ "${isNginxSNIModeInput}" == "5" ]]; then
            inputNginxSNIDomain "trojan"
            inputNginxSNIDomain "website"

            installWebServerNginx
            installTrojanServer

        elif [[ "${isNginxSNIModeInput}" == "6" ]]; then
            inputNginxSNIDomain "v2ray"
            inputNginxSNIDomain "website"

            installWebServerNginx
            installV2ray
            
        fi


        exit
    fi

    inputXraySystemdServiceName "$1"
    renewCertificationWithAcme ""

    echo
    if test -s ${configSSLCertPath}/${configSSLCertFullchainFilename}; then
    
        green " ================================================== "
        green "The certificate file for the domain ${configSSLDomain} has been detected successfully!"
        green " ${configSSLDomain} domain name certificate content file path ${configSSLCertPath}/${configSSLCertFullchainFilename} "
        green " ${configSSLDomain} domain name certificate private key file path ${configSSLCertPath}/${configSSLCertKeyFilename} "        
        green " ================================================== "
        echo

        if [ "$1" == "trojan_nginx" ]; then
            installWebServerNginx
            installTrojanServer

        elif [ "$1" = "trojan" ]; then
            installTrojanServer

        elif [ "$1" = "nginx_v2ray" ]; then
            installWebServerNginx
            installV2ray

        elif [ "$1" = "v2ray_nginxOptional" ]; then
            echo
            green "Whether to install Nginx to provide a fake website, if there is a website or a pagoda panel, please select N not to install"
            read -r -p "Are you sure to install Nginx disguised website? Press Enter to install by default, please enter [Y/n]:" isInstallNginxServerInput
            isInstallNginxServerInput=${isInstallNginxServerInput:-Y}

            if [[ "${isInstallNginxServerInput}" == [Yy] ]]; then
                installWebServerNginx
            fi

            if [[ "${configV2rayWorkingMode}" == "trojan" ]]; then
                installTrojanServer
            fi
            installV2ray

        elif [ "$1" = "v2ray" ]; then
            installV2ray

        elif [ "$1" = "trojan_nginx_v2ray" ]; then
            installWebServerNginx
            installTrojanServer
            installV2ray

        else
            echo
            
        fi
    else
        red " ================================================== "
        red "The application for the https certificate was not successful, and the installation failed!"
        red "Please check whether the domain name and DNS are valid. Please do not apply for the same domain name multiple times in one day!"
        red "Please check whether ports 80 and 443 are open, VPS service providers may need to add additional firewall rules, such as Alibaba Cloud, Google Cloud, etc.!"
        red "Restart the VPS, re-execute the script, you can re-select this item and apply for the certificate again!"
        red " ================================================== "
        exit
    fi    
}




















function downloadTrojanBin(){

    if [ "${isTrojanGo}" = "no" ] ; then
        if [ -z $1 ]; then
            tempDownloadTrojanPath="${configTrojanPath}"
        else
            tempDownloadTrojanPath="${configDownloadTempPath}/upgrade/trojan"
            mv -f ${configDownloadTempPath}/upgrade/trojan/trojan ${configTrojanPath}
        fi    
        # https://github.com/trojan-gfw/trojan/releases/download/v1.16.0/trojan-1.16.0-linux-amd64.tar.xz
        if [[ ${osArchitecture} == "arm" || ${osArchitecture} == "arm64" ]] ; then
            red "Trojan not support arm on linux! "
            exit
        fi

        downloadAndUnzip "https://github.com/trojan-gfw/trojan/releases/download/v${versionTrojan}/${downloadFilenameTrojan}" "${tempDownloadTrojanPath}" "${downloadFilenameTrojan}"
    else
        if [ -z $1 ]; then
            tempDownloadTrojanPath="${configTrojanGoPath}"
        else
            tempDownloadTrojanPath="${configDownloadTempPath}/upgrade/trojan-go"
            mv -f ${configDownloadTempPath}/upgrade/trojan-go/trojan-go ${configTrojanGoPath}
        fi 

        # https://github.com/p4gefau1t/trojan-go/releases/download/v0.10.6/trojan-go-linux-amd64.zip
        if [[ ${osArchitecture} == "arm" ]] ; then
            downloadFilenameTrojanGo="trojan-go-linux-arm.zip"
        fi
        if [[ ${osArchitecture} == "arm64" ]] ; then
            downloadFilenameTrojanGo="trojan-go-linux-armv8.zip"
        fi
        downloadAndUnzip "https://github.com/p4gefau1t/trojan-go/releases/download/v${versionTrojanGo}/${downloadFilenameTrojanGo}" "${tempDownloadTrojanPath}" "${downloadFilenameTrojanGo}"
    fi 
}

function checkTrojanGoInstall(){
    if [ -f "${configTrojanPath}/trojan" ] ; then
        configTrojanBasePath="${configTrojanPath}"
        promptInfoTrojanName=""
        isTrojanGo="no"
    fi

    if [ -f "${configTrojanGoPath}/trojan-go" ] ; then
        configTrojanBasePath="${configTrojanGoPath}"
        promptInfoTrojanName="-go"
        isTrojanGo="yes"
    fi

    if [ -n "$1" ] ; then
        if [[ -f "${configTrojanBasePath}/trojan${promptInfoTrojanName}" ]]; then
            green " =================================================="
            green "Trojan${promptInfoTrojanName} has been installed, exit!"
            green " =================================================="
            exit
        fi
    fi

}

function getTrojanGoInstallInfo(){
    if [ "${isTrojanGo}" = "yes" ] ; then
        getTrojanAndV2rayVersion "trojan-go"
        configTrojanBaseVersion=${versionTrojanGo}
        configTrojanBasePath="${configTrojanGoPath}"
        promptInfoTrojanName="-go"
    else
        getTrojanAndV2rayVersion "trojan"
        configTrojanBaseVersion=${versionTrojan}
        configTrojanBasePath="${configTrojanPath}"
        promptInfoTrojanName=""
    fi
}


function installTrojanServer(){

    trojanPassword1=$(cat /dev/urandom | head -1 | md5sum | head -c 10)
    trojanPassword2=$(cat /dev/urandom | head -1 | md5sum | head -c 10)
    trojanPassword3=$(cat /dev/urandom | head -1 | md5sum | head -c 10)
    trojanPassword4=$(cat /dev/urandom | head -1 | md5sum | head -c 10)
    trojanPassword5=$(cat /dev/urandom | head -1 | md5sum | head -c 10)
    trojanPassword6=$(cat /dev/urandom | head -1 | md5sum | head -c 10)
    trojanPassword7=$(cat /dev/urandom | head -1 | md5sum | head -c 10)
    trojanPassword8=$(cat /dev/urandom | head -1 | md5sum | head -c 10)
    trojanPassword9=$(cat /dev/urandom | head -1 | md5sum | head -c 10)
    trojanPassword10=$(cat /dev/urandom | head -1 | md5sum | head -c 10)



    checkTrojanGoInstall "exitInfo"

    if [ "${isTrojanGoSupportWebsocket}" = "true" ] ; then
        isTrojanGo="yes"
    else
        echo
        green " =================================================="
        green "Please choose to install trojan-go or the original trojan, choose Y to install trojan-go, choose N to install the original trojan"
        read -p "Please choose to install trojan-go or the original trojan? Enter directly and the default is trojan-go, please enter [Y/n]:" isInstallTrojanTypeInput
        isInstallTrojanTypeInput=${isInstallTrojanTypeInput:-Y}

        if [[ "${isInstallTrojanTypeInput}" == [Yy] ]]; then
            isTrojanGo="yes"

            echo
            green "Please choose whether to enable trojan-go Websocket for CDN transfer, note that the original trojan client does not support Websocket"
            read -p "Please choose whether to enable Websocket? Press Enter to enable it by default, please enter [Y/n]:" isTrojanGoWebsocketInput
            isTrojanGoWebsocketInput=${isTrojanGoWebsocketInput:-Y}

            if [[ "${isTrojanGoWebsocketInput}" == [Yy] ]]; then
                isTrojanGoSupportWebsocket="true"
            else
                isTrojanGoSupportWebsocket="false"
            fi

        else
            isTrojanGo="no"
        fi

    fi

    getTrojanGoInstallInfo

    green " =================================================="
    green "Start installing Trojan ${promptInfoTrojanName} Version: ${configTrojanBaseVersion} !"
    green " =================================================="
    echo
    yellow "Please enter trojan${promptInfoTrojanName} password prefix? (several random passwords and passwords with this prefix will be generated)"
    
    read -p "Please enter the prefix of the password, press Enter to generate a random prefix by default:" configTrojanPasswordPrefixInput
    configTrojanPasswordPrefixInput=${configTrojanPasswordPrefixInput:-${configTrojanPasswordPrefixInputDefault}}


    if [[ "$configV2rayWorkingMode" != "trojan" && "$configV2rayWorkingMode" != "sni" ]] ; then
        configV2rayTrojanPort=443

        inputV2rayServerPort "textMainTrojanPort"
        configV2rayTrojanPort=${isTrojanUserPortInput}         
    fi

    configV2rayTrojanReadmePort=${configV2rayTrojanPort}    

    if [[ "$configV2rayWorkingMode" == "sni" ]] ; then
        configSSLCertPath="${configNginxSNIDomainTrojanCertPath}"
        configSSLDomain=${configNginxSNIDomainTrojan}   

        configV2rayTrojanReadmePort=443 
    fi

    rm -rf "${configTrojanBasePath}"
    mkdir -p "${configTrojanBasePath}"
    cd ${configTrojanBasePath}


    downloadTrojanBin

    if [ "${isTrojanMultiPassword}" = "no" ] ; then
    read -r -d '' trojanConfigUserpasswordInput << EOM
        "${trojanPassword1}",
        "${trojanPassword2}",
        "${trojanPassword3}",
        "${trojanPassword4}",
        "${trojanPassword5}",
        "${trojanPassword6}",
        "${trojanPassword7}",
        "${trojanPassword8}",
        "${trojanPassword9}",
        "${trojanPassword10}",
        "${configTrojanPasswordPrefixInput}202001",
        "${configTrojanPasswordPrefixInput}202002",
        "${configTrojanPasswordPrefixInput}202003",
        "${configTrojanPasswordPrefixInput}202004",
        "${configTrojanPasswordPrefixInput}202005",
        "${configTrojanPasswordPrefixInput}202006",
        "${configTrojanPasswordPrefixInput}202007",
        "${configTrojanPasswordPrefixInput}202008",
        "${configTrojanPasswordPrefixInput}202009",
        "${configTrojanPasswordPrefixInput}202010",
        "${configTrojanPasswordPrefixInput}202011",
        "${configTrojanPasswordPrefixInput}202012",
        "${configTrojanPasswordPrefixInput}202013",
        "${configTrojanPasswordPrefixInput}202014",
        "${configTrojanPasswordPrefixInput}202015",
        "${configTrojanPasswordPrefixInput}202016",
        "${configTrojanPasswordPrefixInput}202017",
        "${configTrojanPasswordPrefixInput}202018",
        "${configTrojanPasswordPrefixInput}202019",
        "${configTrojanPasswordPrefixInput}202020"
EOM

    else

    read -r -d '' trojanConfigUserpasswordInput << EOM
        "${trojanPassword1}",
        "${trojanPassword2}",
        "${trojanPassword3}",
        "${trojanPassword4}",
        "${trojanPassword5}",
        "${trojanPassword6}",
        "${trojanPassword7}",
        "${trojanPassword8}",
        "${trojanPassword9}",
        "${trojanPassword10}",
        "${configTrojanPasswordPrefixInput}202000",
        "${configTrojanPasswordPrefixInput}202001",
        "${configTrojanPasswordPrefixInput}202002",
        "${configTrojanPasswordPrefixInput}202003",
        "${configTrojanPasswordPrefixInput}202004",
        "${configTrojanPasswordPrefixInput}202005",
        "${configTrojanPasswordPrefixInput}202006",
        "${configTrojanPasswordPrefixInput}202007",
        "${configTrojanPasswordPrefixInput}202008",
        "${configTrojanPasswordPrefixInput}202009",
        "${configTrojanPasswordPrefixInput}202010",
        "${configTrojanPasswordPrefixInput}202011",
        "${configTrojanPasswordPrefixInput}202012",
        "${configTrojanPasswordPrefixInput}202013",
        "${configTrojanPasswordPrefixInput}202014",
        "${configTrojanPasswordPrefixInput}202015",
        "${configTrojanPasswordPrefixInput}202016",
        "${configTrojanPasswordPrefixInput}202017",
        "${configTrojanPasswordPrefixInput}202018",
        "${configTrojanPasswordPrefixInput}202019",
        "${configTrojanPasswordPrefixInput}202020",
        "${configTrojanPasswordPrefixInput}202021",
        "${configTrojanPasswordPrefixInput}202022",
        "${configTrojanPasswordPrefixInput}202023",
        "${configTrojanPasswordPrefixInput}202024",
        "${configTrojanPasswordPrefixInput}202025",
        "${configTrojanPasswordPrefixInput}202026",
        "${configTrojanPasswordPrefixInput}202027",
        "${configTrojanPasswordPrefixInput}202028",
        "${configTrojanPasswordPrefixInput}202029",
        "${configTrojanPasswordPrefixInput}202030",
        "${configTrojanPasswordPrefixInput}202031",
        "${configTrojanPasswordPrefixInput}202032",
        "${configTrojanPasswordPrefixInput}202033",
        "${configTrojanPasswordPrefixInput}202034",
        "${configTrojanPasswordPrefixInput}202035",
        "${configTrojanPasswordPrefixInput}202036",
        "${configTrojanPasswordPrefixInput}202037",
        "${configTrojanPasswordPrefixInput}202038",
        "${configTrojanPasswordPrefixInput}202039",
        "${configTrojanPasswordPrefixInput}202040",
        "${configTrojanPasswordPrefixInput}202041",
        "${configTrojanPasswordPrefixInput}202042",
        "${configTrojanPasswordPrefixInput}202043",
        "${configTrojanPasswordPrefixInput}202044",
        "${configTrojanPasswordPrefixInput}202045",
        "${configTrojanPasswordPrefixInput}202046",
        "${configTrojanPasswordPrefixInput}202047",
        "${configTrojanPasswordPrefixInput}202048",
        "${configTrojanPasswordPrefixInput}202049",
        "${configTrojanPasswordPrefixInput}202050",
        "${configTrojanPasswordPrefixInput}202051",
        "${configTrojanPasswordPrefixInput}202052",
        "${configTrojanPasswordPrefixInput}202053",
        "${configTrojanPasswordPrefixInput}202054",
        "${configTrojanPasswordPrefixInput}202055",
        "${configTrojanPasswordPrefixInput}202056",
        "${configTrojanPasswordPrefixInput}202057",
        "${configTrojanPasswordPrefixInput}202058",
        "${configTrojanPasswordPrefixInput}202059",
        "${configTrojanPasswordPrefixInput}202060",
        "${configTrojanPasswordPrefixInput}202061",
        "${configTrojanPasswordPrefixInput}202062",
        "${configTrojanPasswordPrefixInput}202063",
        "${configTrojanPasswordPrefixInput}202064",
        "${configTrojanPasswordPrefixInput}202065",
        "${configTrojanPasswordPrefixInput}202066",
        "${configTrojanPasswordPrefixInput}202067",
        "${configTrojanPasswordPrefixInput}202068",
        "${configTrojanPasswordPrefixInput}202069",
        "${configTrojanPasswordPrefixInput}202070",
        "${configTrojanPasswordPrefixInput}202071",
        "${configTrojanPasswordPrefixInput}202072",
        "${configTrojanPasswordPrefixInput}202073",
        "${configTrojanPasswordPrefixInput}202074",
        "${configTrojanPasswordPrefixInput}202075",
        "${configTrojanPasswordPrefixInput}202076",
        "${configTrojanPasswordPrefixInput}202077",
        "${configTrojanPasswordPrefixInput}202078",
        "${configTrojanPasswordPrefixInput}202079",
        "${configTrojanPasswordPrefixInput}202080",
        "${configTrojanPasswordPrefixInput}202081",
        "${configTrojanPasswordPrefixInput}202082",
        "${configTrojanPasswordPrefixInput}202083",
        "${configTrojanPasswordPrefixInput}202084",
        "${configTrojanPasswordPrefixInput}202085",
        "${configTrojanPasswordPrefixInput}202086",
        "${configTrojanPasswordPrefixInput}202087",
        "${configTrojanPasswordPrefixInput}202088",
        "${configTrojanPasswordPrefixInput}202089",
        "${configTrojanPasswordPrefixInput}202090",
        "${configTrojanPasswordPrefixInput}202091",
        "${configTrojanPasswordPrefixInput}202092",
        "${configTrojanPasswordPrefixInput}202093",
        "${configTrojanPasswordPrefixInput}202094",
        "${configTrojanPasswordPrefixInput}202095",
        "${configTrojanPasswordPrefixInput}202096",
        "${configTrojanPasswordPrefixInput}202097",
        "${configTrojanPasswordPrefixInput}202098",
        "${configTrojanPasswordPrefixInput}202099"
EOM

    fi






    if [ "$isTrojanGo" = "no" ] ; then

        # Add trojan server-side configuration
	    cat > ${configTrojanBasePath}/server.json <<-EOF
{
    "run_type": "server",
    "local_addr": "0.0.0.0",
    "local_port": ${configV2rayTrojanPort},
    "remote_addr": "127.0.0.1",
    "remote_port": 80,
    "password": [
        ${trojanConfigUserpasswordInput}
    ],
    "log_level": 1,
    "ssl": {
        "cert": "${configSSLCertPath}/$configSSLCertFullchainFilename",
        "key": "${configSSLCertPath}/$configSSLCertKeyFilename",
        "key_password": "",
        "cipher_tls13":"TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
	    "prefer_server_cipher": true,
        "alpn": [
            "http/1.1"
        ],
        "reuse_session": true,
        "session_ticket": false,
        "session_timeout": 600,
        "plain_http_response": "",
        "curves": "",
        "dhparam": ""
    },
    "tcp": {
        "no_delay": true,
        "keep_alive": true,
        "fast_open": false,
        "fast_open_qlen": 20
    },
    "mysql": {
        "enabled": false,
        "server_addr": "127.0.0.1",
        "server_port": 3306,
        "database": "trojan",
        "username": "trojan",
        "password": ""
    }
}
EOF

        # rm /etc/systemd/system/trojan.service   
        # Add startup script
        cat > ${osSystemMdPath}trojan.service <<-EOF
[Unit]
Description=trojan
After=network.target

[Service]
Type=simple
PIDFile=${configTrojanPath}/trojan.pid
ExecStart=${configTrojanPath}/trojan -l ${configTrojanLogFile} -c "${configTrojanPath}/server.json"
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
RestartPreventExitStatus=23
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
    fi


    if [ "$isTrojanGo" = "yes" ] ; then

        # Add trojan server-side configuration
	    cat > ${configTrojanBasePath}/server.json <<-EOF
{
    "run_type": "server",
    "local_addr": "0.0.0.0",
    "local_port": ${configV2rayTrojanPort},
    "remote_addr": "127.0.0.1",
    "remote_port": 80,
    "password": [
        ${trojanConfigUserpasswordInput}
    ],
    "log_level": 1,
    "log_file": "${configTrojanGoLogFile}",
    "ssl": {
        "verify": true,
        "verify_hostname": true,
        "cert": "${configSSLCertPath}/$configSSLCertFullchainFilename",
        "key": "${configSSLCertPath}/$configSSLCertKeyFilename",
        "sni": "${configSSLDomain}",
        "fallback_addr": "127.0.0.1",
        "fallback_port": 80, 
        "fingerprint": "chrome"
    },
    "websocket": {
        "enabled": ${isTrojanGoSupportWebsocket},
        "path": "/${configTrojanGoWebSocketPath}",
        "host": "${configSSLDomain}"
    }
}
EOF

        # Add startup script
        cat > ${osSystemMdPath}trojan-go.service <<-EOF
[Unit]
Description=trojan-go
After=network.target

[Service]
Type=simple
PIDFile=${configTrojanGoPath}/trojan-go.pid
ExecStart=${configTrojanGoPath}/trojan-go -config "${configTrojanGoPath}/server.json"
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
RestartPreventExitStatus=23

[Install]
WantedBy=multi-user.target
EOF
    fi

    ${sudoCmd} chmod +x ${osSystemMdPath}trojan${promptInfoTrojanName}.service
    ${sudoCmd} systemctl daemon-reload
    ${sudoCmd} systemctl start trojan${promptInfoTrojanName}.service
    ${sudoCmd} systemctl enable trojan${promptInfoTrojanName}.service


    if [ "${configV2rayWorkingMode}" == "nouse" ] ; then
        
    
    # Download and make the command line startup file of the trojan windows client
    rm -rf ${configTrojanBasePath}/trojan-win-cli
    rm -rf ${configTrojanBasePath}/trojan-win-cli-temp
    mkdir -p ${configTrojanBasePath}/trojan-win-cli-temp

    downloadAndUnzip "https://github.com/jinwyp/one_click_script/raw/master/download/trojan-win-cli.zip" "${configTrojanBasePath}" "trojan-win-cli.zip"

    if [ "$isTrojanGo" = "no" ] ; then
        downloadAndUnzip "https://github.com/trojan-gfw/trojan/releases/download/v${versionTrojan}/trojan-${versionTrojan}-win.zip" "${configTrojanBasePath}/trojan-win-cli-temp" "trojan-${versionTrojan}-win.zip"
        mv -f ${configTrojanBasePath}/trojan-win-cli-temp/trojan/trojan.exe ${configTrojanBasePath}/trojan-win-cli/
        mv -f ${configTrojanBasePath}/trojan-win-cli-temp/trojan/VC_redist.x64.exe ${configTrojanBasePath}/trojan-win-cli/
    fi

    if [ "$isTrojanGo" = "yes" ] ; then
        downloadAndUnzip "https://github.com/p4gefau1t/trojan-go/releases/download/v${versionTrojanGo}/trojan-go-windows-amd64.zip" "${configTrojanBasePath}/trojan-win-cli-temp" "trojan-go-windows-amd64.zip"
        mv -f ${configTrojanBasePath}/trojan-win-cli-temp/* ${configTrojanBasePath}/trojan-win-cli/
    fi

    rm -rf ${configTrojanBasePath}/trojan-win-cli-temp
    cp ${configSSLCertPath}/${configSSLCertFullchainFilename} ${configTrojanBasePath}/trojan-win-cli/${configSSLCertFullchainFilename}

    cat > ${configTrojanBasePath}/trojan-win-cli/config.json <<-EOF
{
    "run_type": "client",
    "local_addr": "127.0.0.1",
    "local_port": 1080,
    "remote_addr": "${configSSLDomain}",
    "remote_port": 443,
    "password": [
        "${trojanPassword1}"
    ],
    "log_level": 1,
    "ssl": {
        "verify": true,
        "verify_hostname": true,
        "cert": "$configSSLCertFullchainFilename",
        "cipher_tls13":"TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
	    "sni": "",
        "alpn": [
            "h2",
            "http/1.1"
        ],
        "reuse_session": true,
        "session_ticket": false,
        "curves": ""
    },
    "tcp": {
        "no_delay": true,
        "keep_alive": true,
        "fast_open": false,
        "fast_open_qlen": 20
    }
}
EOF

    zip -r ${configWebsiteDownloadPath}/trojan-win-cli.zip ${configTrojanBasePath}/trojan-win-cli/

    fi



    # Set up cron scheduled tasks
    # https://stackoverflow.com/questions/610839/how-can-i-programmatically-create-a-new-cron-job

    # (crontab -l 2>/dev/null | grep -v '^[a-zA-Z]'; echo "15 4 * * 0,1,2,3,4,5,6 systemctl restart trojan.service") | sort - | uniq - | crontab -
    (crontab -l ; echo "10 4 * * 0,1,2,3,4,5,6 systemctl restart trojan${promptInfoTrojanName}.service") | sort - | uniq - | crontab -


	green "======================================================================"
	green " Trojan${promptInfoTrojanName} Version: ${configTrojanBaseVersion} Installed successfully!"

    if [[ ${configInstallNginxMode} == "noSSL" ]]; then
        green "Pretend the site is https://${configSSLDomain}"
	    green "The static html content of the disguised site is placed in the directory ${configWebsitePath}, and the content of the website can be replaced by yourself!"
    fi

	red "Trojan${promptInfoTrojanName} server-side configuration path ${configTrojanBasePath}/server.json "
	red " Trojan${promptInfoTrojanName} run log file path: ${configTrojanLogFile} "
	green " Trojan${promptInfoTrojanName} View log command: journalctl -n 50 -u trojan${promptInfoTrojanName}.service "

	green " Trojan${promptInfoTrojanName} stop command: systemctl stop trojan${promptInfoTrojanName}.service start command: systemctl start trojan${promptInfoTrojanName}.service restart command: systemctl restart trojan${promptInfoTrojanName}.service"
	green " Trojan${promptInfoTrojanName} View running status command: systemctl status trojan${promptInfoTrojanName}.service "
	green "The Trojan${promptInfoTrojanName} server will automatically restart every day to prevent memory leaks. Run the crontab -l command to view the scheduled restart command!"
	green "======================================================================"
	# blue  "----------------------------------------"
    echo
	yellow "Trojan${promptInfoTrojanName} configuration information is as follows, please copy and save by yourself, choose one of the passwords!"
	yellow "Server Address: ${configSSLDomain} Port: ${configV2rayTrojanReadmePort}"
	yellow "Password1: ${trojanPassword1}"
	yellow "Password2: ${trojanPassword2}"
	yellow "Password 3: ${trojanPassword3}"
	yellow "Password 4: ${trojanPassword4}"
	yellow "Password 5: ${trojanPassword5}"
	yellow "Password 6: ${trojanPassword6}"
	yellow "Password 7: ${trojanPassword7}"
	yellow "Password 8: ${trojanPassword8}"
	yellow "Password 9: ${trojanPassword9}"
	yellow "Password 10: ${trojanPassword10}"

    tempTextInfoTrojanPassword="You specify a prefix of 100 passwords: from ${configTrojanPasswordPrefixInput}202000 to ${configTrojanPasswordPrefixInput}202099 can be used"
    if [ "${isTrojanMultiPassword}" = "no" ] ; then
        tempTextInfoTrojanPassword="You specify a prefix of 20 passwords: from ${configTrojanPasswordPrefixInput}202001 to ${configTrojanPasswordPrefixInput}202020 can be used"
    fi
	yellow "${tempTextInfoTrojanPassword}" 
	yellow "For example: password: ${configTrojanPasswordPrefixInput}202002 or password: ${configTrojanPasswordPrefixInput}202019 can be used"

    if [[ ${isTrojanGoSupportWebsocket} == "true" ]]; then
        yellow "Websocket path path is: /${configTrojanGoWebSocketPath}"
        # yellow "Websocket obfuscation_password obfuscated password is: ${trojanPasswordWS}"
        yellow "Websocket double TLS is: true on"
    fi

    echo
    green "======================================================================"
    yellow "Trojan${promptInfoTrojanName} Shadowrocket link address"

    if [ "$isTrojanGo" = "yes" ] ; then
        if [[ ${isTrojanGoSupportWebsocket} == "true" ]]; then
            green " trojan://${trojanPassword1}@${configSSLDomain}:${configV2rayTrojanReadmePort}?peer=${configSSLDomain}&sni=${configSSLDomain}&plugin=obfs-local;obfs=websocket;obfs-host=${configSSLDomain};obfs-uri=/${configTrojanGoWebSocketPath}#${configSSLDomain}_trojan_go_ws"
            echo
            yellow " QR code Trojan${promptInfoTrojanName} "
		    green "https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=trojan%3a%2f%2f${trojanPassword1}%40${configSSLDomain}%3a${configV2rayTrojanReadmePort}%3fallowInsecure%3d0%26peer%3d${configSSLDomain}%26plugin%3dobfs-local%3bobfs%3dwebsocket%3bobfs-host%3d${configSSLDomain}%3bobfs-uri%3d/${configTrojanGoWebSocketPath}%23${configSSLDomain}_trojan_go_ws"

            echo
            yellow " Trojan${promptInfoTrojanName} QV2ray link address"
            green " trojan-go://${trojanPassword1}@${configSSLDomain}:${configV2rayTrojanReadmePort}?sni=${configSSLDomain}&type=ws&host=${configSSLDomain}&path=%2F${configTrojanGoWebSocketPath}#${configSSLDomain}_trojan_go_ws"
        
        else
            green " trojan://${trojanPassword1}@${configSSLDomain}:${configV2rayTrojanReadmePort}?peer=${configSSLDomain}&sni=${configSSLDomain}#${configSSLDomain}_trojan_go"
            echo
            yellow " QR code Trojan${promptInfoTrojanName} "
            green "https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=trojan%3a%2f%2f${trojanPassword1}%40${configSSLDomain}%3a${configV2rayTrojanReadmePort}%3fpeer%3d${configSSLDomain}%26sni%3d${configSSLDomain}%23${configSSLDomain}_trojan_go"

            echo
            yellow " Trojan${promptInfoTrojanName} QV2ray link address"
            green " trojan-go://${trojanPassword1}@${configSSLDomain}:${configV2rayTrojanReadmePort}?sni=${configSSLDomain}&type=original&host=${configSSLDomain}#${configSSLDomain}_trojan_go"
        fi

    else
        green " trojan://${trojanPassword1}@${configSSLDomain}:${configV2rayTrojanReadmePort}?peer=${configSSLDomain}&sni=${configSSLDomain}#${configSSLDomain}_trojan"
        echo
        yellow " QR code Trojan${promptInfoTrojanName} "
		green "https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=trojan%3a%2f%2f${trojanPassword1}%40${configSSLDomain}%3a${configV2rayTrojanReadmePort}%3fpeer%3d${configSSLDomain}%26sni%3d${configSSLDomain}%23${configSSLDomain}_trojan"

    fi

	echo
	green "======================================================================"
	green "Please download the corresponding trojan client:"
	yellow "1 Windows client download: http://${configSSLDomain}/download/${configTrojanWindowsCliPrefixPath}/v2ray-windows.zip"
	#yellow "Another version download for Windows client: http://${configSSLDomain}/download/${configTrojanWindowsCliPrefixPath}/trojan-Qt5-windows.zip"
	#yellow "Windows client command line version download: http://${configSSLDomain}/download/${configTrojanWindowsCliPrefixPath}/trojan-win-cli.zip"
	#yellow "The Windows client command line version needs to be used with browser plugins, such as switchyomega, etc.! "
    yellow "2 MacOS client download: http://${configSSLDomain}/download/${configTrojanWindowsCliPrefixPath}/v2ray-mac.zip"
    yellow "MacOS another client download: http://${configSSLDomain}/download/${configTrojanWindowsCliPrefixPath}/trojan-mac.zip"
    #yellow "MacOS client Trojan-Qt5 download: http://${configSSLDomain}/download/${configTrojanWindowsCliPrefixPath}/trojan-Qt5-mac.zip"
    yellow "3 Android client download https://github.com/trojan-gfw/igniter/releases "
    yellow "Another client download for Android https://github.com/2dust/v2rayNG/releases"
    yellow "Android Client Clash Download https://github.com/Kr328/ClashForAndroid/releases"
    yellow "4 iOS client please install Little Rocket https://shadowsockshelp.github.io/ios/ "
    yellow " iOS please install Xiaorocket another address https://lueyingpro.github.io/shadowrocket/index.html "
    yellow " iOS installation of small rocket encountered problems tutorial https://github.com/shadowrocketHelp/help/ "
    green "======================================================================"
	green "Tutorials and other resources:"
	green "Visit https://www.v2rayssr.com/vpn-client.html to download the client and tutorial"
	#green "Visit https://www.v2rayssr.com/trojan-1.html to download the browser plug-in client and tutorial"
    green "Visit https://westworldss.com/portal/page/download to download the client and tutorial"
	green "======================================================================"
	green "Other Windows clients:"
	green "https://dl.trojan-cdn.com/trojan (exe is Win client, dmg is Mac client)"
	green "https://github.com/Qv2ray/Qv2ray/releases (exe is Win client, dmg is Mac client)"
	green "https://github.com/Dr-Incognito/V2Ray-Desktop/releases (exe is Win client, dmg is Mac client)"
	green "https://github.com/Fndroid/clash_for_windows_pkg/releases"
	green "======================================================================"
	green "Other Mac clients:"
	green "https://dl.trojan-cdn.com/trojan (exe is Win client, dmg is Mac client)"
	green "https://github.com/Qv2ray/Qv2ray/releases (exe is Win client, dmg is Mac client)"
	green "https://github.com/Dr-Incognito/V2Ray-Desktop/releases (exe is Win client, dmg is Mac client)"
	green "https://github.com/JimLee1996/TrojanX/releases (exe for Win client, dmg for Mac client)"
	green "https://github.com/yichengchen/clashX/releases "
	green "======================================================================"
	green "Other Android clients:"
	green "https://github.com/trojan-gfw/igniter/releases "
	green "https://github.com/Kr328/ClashForAndroid/releases "
	green "======================================================================"


    cat >> ${configReadme} <<-EOF

Trojan${promptInfoTrojanName} Version: ${configTrojanBaseVersion} Installed successfully !
Trojan${promptInfoTrojanName} server-side configuration path${configTrojanBasePath}/server.json

Trojan${promptInfoTrojanName} run log file path: ${configTrojanLogFile}
Trojan${promptInfoTrojanName} View log command: journalctl -n 50 -u trojan${promptInfoTrojanName}.service

Trojan${promptInfoTrojanName} start command: systemctl start trojan${promptInfoTrojanName}.service
Trojan${promptInfoTrojanName} stop command: systemctl stop trojan${promptInfoTrojanName}.service  
Trojan${promptInfoTrojanName} restart command: systemctl restart trojan${promptInfoTrojanName}.service
Trojan${promptInfoTrojanName} View running status command: systemctl status trojan${promptInfoTrojanName}.service

Trojan${promptInfoTrojanName}Server Address: ${configSSLDomain} Port: ${configV2rayTrojanReadmePort}

Password1: ${trojanPassword1}
Password2: ${trojanPassword2}
Password3: ${trojanPassword3}
Password 4: ${trojanPassword4}
Password 5: ${trojanPassword5}
Password 6: ${trojanPassword6}
Password 7: ${trojanPassword7}
Password8: ${trojanPassword8}
Password9: ${trojanPassword9}
Password10: ${trojanPassword10}
${tempTextInfoTrojanPassword}
For example: password:${configTrojanPasswordPrefixInput}202002 or password:${configTrojanPasswordPrefixInput}202019 can be used

If trojan-go enables Websocket, then the Websocket path path is: /${configTrojanGoWebSocketPath}

Little Rocket Link:
trojan://${trojanPassword1}@${configSSLDomain}:${configV2rayTrojanReadmePort}?peer=${configSSLDomain}&sni=${configSSLDomain}#${configSSLDomain}_trojan"

QR code Trojan${promptInfoTrojanName}
https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=trojan%3a%2f%2f${trojanPassword1}%40${configSSLDomain}%3a${configV2rayTrojanReadmePort}%3fpeer%3d${configSSLDomain}%26sni%3d${configSSLDomain}%23${configSSLDomain}_trojan

EOF
}

function upgradeTrojan(){

    checkTrojanGoInstall

    if [[ -f "${configTrojanPath}/trojan" || -f "${configTrojanGoPath}/trojan-go" ]]; then

        getTrojanGoInstallInfo

        green " ================================================== "
        green "Start upgrading Trojan${promptInfoTrojanName} Version: ${configTrojanBaseVersion}"
        green " ================================================== "

        ${sudoCmd} systemctl stop trojan${promptInfoTrojanName}.service
        mkdir -p ${configDownloadTempPath}/upgrade/trojan${promptInfoTrojanName}
        downloadTrojanBin "upgrade"
        ${sudoCmd} systemctl start trojan${promptInfoTrojanName}.service

        green " ================================================== "
        green "Upgrade successfully Trojan${promptInfoTrojanName} Version: ${configTrojanBaseVersion} !"
        green " ================================================== "

    else
        red "The system is not installed trojan${promptInfoTrojanName}, exit uninstall"
    fi
}

function removeTrojan(){

    echo
    read -p "Are you sure to uninstall trojan or trojan-go? Press Enter to uninstall by default, please enter [Y/n]:" isRemoveTrojanServerInput
    isRemoveTrojanServerInput=${isRemoveTrojanServerInput:-Y}

    if [[ "${isRemoveTrojanServerInput}" == [Yy] ]]; then
        

        echo
        checkTrojanGoInstall

        if [[ -f "${configTrojanPath}/trojan" || -f "${configTrojanGoPath}/trojan-go" ]]; then
            echo
            green " ================================================== "
            red "Ready to uninstall installed trojan${promptInfoTrojanName}"
            green " ================================================== "
            echo

            ${sudoCmd} systemctl stop trojan${promptInfoTrojanName}.service
            ${sudoCmd} systemctl disable trojan${promptInfoTrojanName}.service

            rm -rf ${configTrojanBasePath}
            rm -f ${osSystemMdPath}trojan${promptInfoTrojanName}.service
            rm -f ${configTrojanLogFile}
            rm -f ${configTrojanGoLogFile}

            rm -f ${configReadme}

            crontab -l | grep -v "trojan${promptInfoTrojanName}"  | crontab -

            echo
            green " ================================================== "
            green " trojan${promptInfoTrojanName} uninstall complete!"
            green "The deletion of crontab scheduled tasks is complete!"
            green " ================================================== "
            
        else
            red "The system is not installed trojan${promptInfoTrojanName}, exit uninstall"
        fi

    fi
}


































function downloadV2rayXrayBin(){
    if [ -z $1 ]; then
        tempDownloadV2rayPath="${configV2rayPath}"
    else
        tempDownloadV2rayPath="${configDownloadTempPath}/upgrade/${promptInfoXrayName}"
    fi

    if [ "$isXray" = "no" ] ; then
        # https://github.com/v2fly/v2ray-core/releases/download/v4.41.1/v2ray-linux-64.zip
        # https://github.com/v2fly/v2ray-core/releases/download/v4.41.1/v2ray-linux-arm32-v6.zip
        # https://github.com/v2fly/v2ray-core/releases/download/v4.44.0/v2ray-linux-arm64-v8a.zip
        
        if [[ ${osArchitecture} == "arm" ]] ; then
            downloadFilenameV2ray="v2ray-linux-arm32-v6.zip"
        fi
        if [[ ${osArchitecture} == "arm64" ]] ; then
            downloadFilenameV2ray="v2ray-linux-arm64-v8a.zip"
        fi

        downloadAndUnzip "https://github.com/v2fly/v2ray-core/releases/download/v${versionV2ray}/${downloadFilenameV2ray}" "${tempDownloadV2rayPath}" "${downloadFilenameV2ray}"

    else
        # https://github.com/XTLS/Xray-core/releases/download/v1.5.0/Xray-linux-64.zip
        # https://github.com/XTLS/Xray-core/releases/download/v1.5.2/Xray-linux-arm32-v6.zip
        if [[ ${osArchitecture} == "arm" ]] ; then
            downloadFilenameXray="Xray-linux-arm32-v6.zip"
        fi
        if [[ ${osArchitecture} == "arm64" ]] ; then
            downloadFilenameXray="Xray-linux-arm64-v8a.zip"
        fi

        downloadAndUnzip "https://github.com/XTLS/Xray-core/releases/download/v${versionXray}/${downloadFilenameXray}" "${tempDownloadV2rayPath}" "${downloadFilenameXray}"
    fi
}



function inputV2rayStreamSettings(){
    echo
    green " =================================================="
    yellow "Please select the StreamSettings transport protocol of V2ray or Xray, the default is 3 Websocket"
    echo
    green " 1. TCP "
    green " 2. KCP "
    green " 3. WebSocket supports CDN"
    green " 4. HTTP/2 (note that Nginx does not support HTTP/2 forwarding)"
    green " 5. QUIC "
    green " 6. gRPC supports CDN"
    green " 7. WebSocket + gRPC 支持CDN"
    echo
    read -p "Please select the transmission protocol? Press Enter to select 3 Websocket by default, please enter pure numbers:" isV2rayStreamSettingInput
    isV2rayStreamSettingInput=${isV2rayStreamSettingInput:-3}

    if [[ $isV2rayStreamSettingInput == 1 ]]; then
        configV2rayStreamSetting="tcp"

    elif [[ $isV2rayStreamSettingInput == 2 ]]; then
        configV2rayStreamSetting="kcp"
        inputV2rayKCPSeedPassword

    elif [[ $isV2rayStreamSettingInput == 4 ]]; then
        configV2rayStreamSetting="h2"
        inputV2rayWSPath "h2"
    elif [[ $isV2rayStreamSettingInput == 5 ]]; then
        configV2rayStreamSetting="what"
        inputV2rayKCPSeedPassword "quic"

    elif [[ $isV2rayStreamSettingInput == 6 ]]; then
        configV2rayStreamSetting="grpc"

    elif [[ $isV2rayStreamSettingInput == 7 ]]; then
        configV2rayStreamSetting="wsgrpc"

    else
        configV2rayStreamSetting="ws"
        inputV2rayWSPath
    fi


    if [[ "${configInstallNginxMode}" == "v2raySSL" || ${configV2rayWorkingNotChangeMode} == "true" ]]; then

         if [[ "${configV2rayStreamSetting}" == "grpc" ]]; then
            inputV2rayGRPCPath

        elif [[ "${configV2rayStreamSetting}" == "wsgrpc" ]]; then
            inputV2rayWSPath
            inputV2rayGRPCPath
        fi

    else

        if [[ "${configV2rayStreamSetting}" == "grpc" ]]; then
            inputV2rayServerPort "textMainGRPCPort"

            configV2rayGRPCPort=${isV2rayUserPortGRPCInput}   
            configV2rayPortGRPCShowInfo=${isV2rayUserPortGRPCInput}   

            inputV2rayGRPCPath

        elif [[ "${configV2rayStreamSetting}" == "wsgrpc" ]]; then
            inputV2rayWSPath

            inputV2rayServerPort "textMainGRPCPort"

            configV2rayGRPCPort=${isV2rayUserPortGRPCInput}   
            configV2rayPortGRPCShowInfo=${isV2rayUserPortGRPCInput}   

            inputV2rayGRPCPath
        fi

    fi
}

function inputV2rayKCPSeedPassword(){ 
    echo
    configV2rayKCPSeedPassword=$(cat /dev/urandom | head -1 | md5sum | head -c 4)

    configV2rayKCPQuicText="KCP's Seed Obfuscated Password"
    if [[ $1 == "quic" ]]; then
        configV2rayKCPQuicText="QUIC key key"
    fi 

    read -p "Do you want to customize ${configV2rayKCPQuicText} of ${promptInfoXrayName}? Press Enter to create a random password by default, please enter a custom password:" isV2rayUserKCPSeedInput
    isV2rayUserKCPSeedInput=${isV2rayUserKCPSeedInput:-${configV2rayKCPSeedPassword}}

    if [[ -z $isV2rayUserKCPSeedInput ]]; then
        echo
    else
        configV2rayKCPSeedPassword=${isV2rayUserKCPSeedInput}
    fi
}


function inputV2rayWSPath(){ 
    echo
    configV2rayWebSocketPath=$(cat /dev/urandom | head -1 | md5sum | head -c 8)

    configV2rayWSH2Text="WS"
    if [[ $1 == "h2" ]]; then
        configV2rayWSH2Text="HTTP2"
    fi

    read -p "Do you want to customize the Path of ${configV2rayWSH2Text} of ${promptInfoXrayName}? Press Enter to create a random path by default, please enter a custom path (do not enter /):" isV2rayUserWSPathInput
    isV2rayUserWSPathInput=${isV2rayUserWSPathInput:-${configV2rayWebSocketPath}}

    if [[ -z $isV2rayUserWSPathInput ]]; then
        echo
    else
        configV2rayWebSocketPath=${isV2rayUserWSPathInput}
    fi
}

function inputV2rayGRPCPath(){ 
    echo
    configV2rayGRPCServiceName=$(cat /dev/urandom | head -1 | md5sum | head -c 8)

    read -p "Do you want to customize the gRPC serviceName of ${promptInfoXrayName}? Press Enter to create a random path by default, please enter a custom path (do not enter /):" isV2rayUserGRPCPathInput
    isV2rayUserGRPCPathInput=${isV2rayUserGRPCPathInput:-${configV2rayGRPCServiceName}}

    if [[ -z $isV2rayUserGRPCPathInput ]]; then
        echo
    else
        configV2rayGRPCServiceName=${isV2rayUserGRPCPathInput}
    fi
}


function inputV2rayServerPort(){  
    echo
	if [[ $1 == "textMainPort" ]]; then
        green "Do you want to customize the port number of ${promptInfoXrayName}? To support cloudflare's CDN, you need to use the HTTPS port number supported by cloudflare, such as 443 8443 2053 2083 2087 2096 port"
        green " For details, please refer to the official cloudflare documentation https://developers.cloudflare.com/fundamentals/get-started/network-ports"
        read -p "Do you want to customize the port number of ${promptInfoXrayName}? Enter the default value of ${configV2rayPortShowInfo}, please enter the custom port number [1-65535]:" isV2rayUserPortInput
        isV2rayUserPortInput=${isV2rayUserPortInput:-${configV2rayPortShowInfo}}
		checkPortInUse "${isV2rayUserPortInput}" $1 
	fi

	if [[ $1 == "textMainGRPCPort" ]]; then
        green "If you use gRPC protocol and want to support cloudflare's CDN, you need to enter port 443"
        read -p "Do you want to customize the port number of ${promptInfoXrayName} gRPC? Enter the default value of ${configV2rayPortGRPCShowInfo}, please enter the custom port number [1-65535]:" isV2rayUserPortGRPCInput
        isV2rayUserPortGRPCInput=${isV2rayUserPortGRPCInput:-${configV2rayPortGRPCShowInfo}}
		checkPortInUse "${isV2rayUserPortGRPCInput}" $1 
	fi    

	if [[ $1 == "textAdditionalPort" ]]; then
        green "Whether to add an additional listening port to work concurrently with the main port ${configV2rayPort}"
        green "Generally used when the relay machine cannot use port 443 to relay to the target host using an extra port"
        read -p "Would you like to add an additional listening port to ${promptInfoXrayName}? Enter the default No, please enter the additional port number [1-65535]:" isV2rayAdditionalPortInput
        isV2rayAdditionalPortInput=${isV2rayAdditionalPortInput:-999999}
        checkPortInUse "${isV2rayAdditionalPortInput}" $1 
	fi


    if [[ $1 == "textMainTrojanPort" ]]; then
        green "Do you want to customize the port number of Trojan${promptInfoTrojanName}? Enter directly and default to ${configV2rayTrojanPort}"
        read -p "Do you want to customize the port number of Trojan${promptInfoTrojanName}? Enter directly and the default is ${configV2rayTrojanPort}, please enter the custom port number [1-65535]:" isTrojanUserPortInput
        isTrojanUserPortInput=${isTrojanUserPortInput:-${configV2rayTrojanPort}}
		checkPortInUse "${isTrojanUserPortInput}" $1 
	fi    
}

function checkPortInUse(){ 
    if [ $1 = "999999" ]; then
        echo
    elif [[ $1 -gt 1 && $1 -le 65535 ]]; then
        isPortUsed=$(netstat -tulpn | grep -e ":$1") ;
        if [ -z "${isPortUsed}" ]; then 
            green "The input port number $1 is not used, continue to install..."  
            
        else
            processInUsedName=$(echo "${isPortUsed}" | awk '{print $7}' | awk -F"/" '{print $2}')
            red "The input port number $1 is already occupied by ${processInUsedName}! Please exit the installation, check if the port is occupied or re-enter!"  
            inputV2rayServerPort $2
        fi
    else
        red "Incorrect port number! Must be [1-65535]. Please re-enter"
        inputV2rayServerPort $2 
    fi
}


v2rayVmessLinkQR1=""
v2rayVmessLinkQR2=""
v2rayVlessLinkQR1=""
v2rayVlessLinkQR2=""
v2rayPassword1UrlEncoded=""

function rawUrlEncode() {
    # https://stackoverflow.com/questions/296536/how-to-urlencode-data-for-curl-command


    local string="${1}"
    local strlen=${#string}
    local encoded=""
    local pos c o

    for (( pos=0 ; pos<strlen ; pos++ )); do
        c=${string:$pos:1}
        case "$c" in
            [-_.~a-zA-Z0-9] ) o="${c}" ;;
            * )               printf -v o '%%%02x' "'$c"
        esac
        encoded+="${o}"
    done
    echo
    green "== URL Encoded: ${encoded}"    # You can either set a return variable (FASTER) 
    v2rayPassword1UrlEncoded="${encoded}"   #+or echo the result (EASIER)... or both... :p
}

function generateVmessImportLink(){
    # https://github.com/2dust/v2rayN/wiki/%E5%88%86%E4%BA%AB%E9%93%BE%E6%8E%A5%E6%A0%BC%E5%BC%8F%E8%AF%B4%E6%98%8E(ver-2)

    configV2rayVmessLinkConfigTls="tls"
    if [[ "${configV2rayIsTlsShowInfo}" == "none" ]]; then
        configV2rayVmessLinkConfigTls=""
    fi

    configV2rayVmessLinkStreamSetting1="${configV2rayStreamSetting}"
    configV2rayVmessLinkStreamSetting2=""
    if [[ "${configV2rayStreamSetting}" == "wsgrpc" ]]; then
        configV2rayVmessLinkStreamSetting1="ws"
        configV2rayVmessLinkStreamSetting2="grpc"
    fi

    configV2rayProtocolDisplayName="${configV2rayProtocol}"
    configV2rayProtocolDisplayHeaderType="none"
    configV2rayVmessLinkConfigPath=""
    configV2rayVmessLinkConfigPath2=""

    if [[ "${configV2rayWorkingMode}" == "vlessTCPVmessWS" ]]; then
        configV2rayVmessLinkStreamSetting1="ws"
        configV2rayVmessLinkStreamSetting2="tcp"

        configV2rayVmessLinkConfigPath="${configV2rayWebSocketPath}"
        configV2rayVmessLinkConfigPath2="/tcp${configV2rayWebSocketPath}" 

        configV2rayVmessLinkConfigTls="tls" 

        configV2rayProtocolDisplayName="vmess"

        configV2rayProtocolDisplayHeaderType="http"
    fi



    configV2rayVmessLinkConfigHost="${configSSLDomain}"
    if [[ "${configV2rayStreamSetting}" == "quic" ]]; then
        configV2rayVmessLinkConfigHost="none"
    fi


    if [[ "${configV2rayStreamSetting}" == "kcp" || "${configV2rayStreamSetting}" == "quic" ]]; then
        configV2rayVmessLinkConfigPath="${configV2rayKCPSeedPassword}"

    elif [[ "${configV2rayStreamSetting}" == "h2" || "${configV2rayStreamSetting}" == "ws" ]]; then
        configV2rayVmessLinkConfigPath="${configV2rayWebSocketPath}"

    elif [[ "${configV2rayStreamSetting}" == "grpc" ]]; then
        configV2rayVmessLinkConfigPath="${configV2rayGRPCServiceName}"

    elif [[ "${configV2rayStreamSetting}" == "wsgrpc" ]]; then
        configV2rayVmessLinkConfigPath="${configV2rayWebSocketPath}"
        configV2rayVmessLinkConfigPath2="${configV2rayGRPCServiceName}"
    fi

    cat > ${configV2rayVmessImportLinkFile1Path} <<-EOF
{
    "v": "2",
    "ps": "${configSSLDomain}_${configV2rayProtocolDisplayName}_${configV2rayVmessLinkStreamSetting1}",
    "add": "${configSSLDomain}",
    "port": "${configV2rayPortShowInfo}",
    "id": "${v2rayPassword1}",
    "aid": "0",
    "net": "${configV2rayVmessLinkStreamSetting1}",
    "type": "none",
    "host": "${configV2rayVmessLinkConfigHost}",
    "path": "${configV2rayVmessLinkConfigPath}",
    "tls": "${configV2rayVmessLinkConfigTls}",
    "sni": "${configSSLDomain}"
}

EOF

    cat > ${configV2rayVmessImportLinkFile2Path} <<-EOF
{
    "v": "2",
    "ps": "${configSSLDomain}_${configV2rayProtocolDisplayName}_${configV2rayVmessLinkStreamSetting2}",
    "add": "${configSSLDomain}",
    "port": "${configV2rayPortShowInfo}",
    "id": "${v2rayPassword1}",
    "aid": "0",
    "net": "${configV2rayVmessLinkStreamSetting2}",
    "type": "${configV2rayProtocolDisplayHeaderType}",
    "host": "${configV2rayVmessLinkConfigHost}",
    "path": "${configV2rayVmessLinkConfigPath2}",
    "tls": "${configV2rayVmessLinkConfigTls}",
    "sni": "${configSSLDomain}"
}

EOF

    v2rayVmessLinkQR1="vmess://$(cat ${configV2rayVmessImportLinkFile1Path} | base64 -w 0)"
    v2rayVmessLinkQR2="vmess://$(cat ${configV2rayVmessImportLinkFile2Path} | base64 -w 0)"
}

function generateVLessImportLink(){
    # https://github.com/XTLS/Xray-core/discussions/716


    generateVmessImportLink
    rawUrlEncode "${v2rayPassword1}"

    if [[ "${configV2rayStreamSetting}" == "" ]]; then

        configV2rayVlessXtlsFlow="tls"
        configV2rayVlessXtlsFlowShowInfo="空"
        if [[ "${configV2rayIsTlsShowInfo}" == "xtls" ]]; then
            configV2rayVlessXtlsFlow="xtls&flow=xtls-rprx-direct"
            configV2rayVlessXtlsFlowShowInfo="xtls-rprx-direct"
        fi

        if [[ "$configV2rayWorkingMode" == "vlessgRPC" ]]; then
            cat > ${configV2rayVlessImportLinkFile1Path} <<-EOF
${configV2rayProtocol}://${v2rayPassword1UrlEncoded}@${configSSLDomain}:${configV2rayPortShowInfo}?encryption=none&security=${configV2rayVlessXtlsFlow}&type=grpc&host=${configSSLDomain}&serviceName=%2f${configV2rayGRPCServiceName}#${configSSLDomain}+gRPC_protocol
EOF
        else
            cat > ${configV2rayVlessImportLinkFile1Path} <<-EOF
${configV2rayProtocol}://${v2rayPassword1UrlEncoded}@${configSSLDomain}:${configV2rayPortShowInfo}?encryption=none&security=${configV2rayVlessXtlsFlow}&type=tcp&host=${configSSLDomain}#${configSSLDomain}+TCP_protocol
EOF

            cat > ${configV2rayVlessImportLinkFile2Path} <<-EOF
${configV2rayProtocol}://${v2rayPassword1UrlEncoded}@${configSSLDomain}:${configV2rayPortShowInfo}?encryption=none&security=tls&type=ws&host=${configSSLDomain}&path=%2f${configV2rayWebSocketPath}#${configSSLDomain}+WebSocket_protocol
EOF
        fi

        v2rayVlessLinkQR1="$(cat ${configV2rayVlessImportLinkFile1Path})"
        v2rayVlessLinkQR2="$(cat ${configV2rayVlessImportLinkFile2Path})"
    else

	    if [[ "${configV2rayProtocol}" == "vless" ]]; then

            cat > ${configV2rayVlessImportLinkFile1Path} <<-EOF
${configV2rayProtocol}://${v2rayPassword1UrlEncoded}@${configSSLDomain}:${configV2rayPortShowInfo}?encryption=none&security=${configV2rayIsTlsShowInfo}&type=${configV2rayVmessLinkStreamSetting1}&host=${configSSLDomain}&path=%2f${configV2rayVmessLinkConfigPath}&headerType=none&seed=${configV2rayKCPSeedPassword}&quicSecurity=none&key=${configV2rayKCPSeedPassword}&serviceName=${configV2rayVmessLinkConfigPath}#${configSSLDomain}+${configV2rayVmessLinkStreamSetting1}_protocol
EOF
            cat > ${configV2rayVlessImportLinkFile2Path} <<-EOF
${configV2rayProtocol}://${v2rayPassword1UrlEncoded}@${configSSLDomain}:${configV2rayPortShowInfo}?encryption=none&security=${configV2rayIsTlsShowInfo}&type=${configV2rayVmessLinkStreamSetting2}&host=${configSSLDomain}&path=%2f${configV2rayVmessLinkConfigPath2}&headerType=none&seed=${configV2rayKCPSeedPassword}&quicSecurity=none&key=${configV2rayKCPSeedPassword}&serviceName=${configV2rayVmessLinkConfigPath2}#${configSSLDomain}+${configV2rayVmessLinkStreamSetting2}_protocol
EOF

            v2rayVlessLinkQR1="$(cat ${configV2rayVlessImportLinkFile1Path})"
            v2rayVlessLinkQR2="$(cat ${configV2rayVlessImportLinkFile2Path})"
	    fi

    fi
}




function inputUnlockV2rayServerInfo(){
            echo
            yellow "Please select a protocol for a V2ray or Xray server to unlock streaming"
            green " 1. VLess + TCP + TLS"
            green " 2. VLess + TCP + XTLS"
            green " 3. VLess + WS + TLS (支持CDN)"
            green " 4. VMess + TCP + TLS"
            green " 5. VMess + WS + TLS (支持CDN)"
            echo
            read -p "Please select a protocol? Press Enter to select 3 by default, please enter pure numbers:" isV2rayUnlockServerProtocolInput
            isV2rayUnlockServerProtocolInput=${isV2rayUnlockServerProtocolInput:-3}

            isV2rayUnlockOutboundServerProtocolText="vless"
            if [[ $isV2rayUnlockServerProtocolInput == "4" || $isV2rayUnlockServerProtocolInput == "5" ]]; then
                isV2rayUnlockOutboundServerProtocolText="vmess"
            fi

            isV2rayUnlockOutboundServerTCPText="tcp"
            unlockOutboundServerWebSocketSettingText=""
            if [[ $isV2rayUnlockServerProtocolInput == "3" ||  $isV2rayUnlockServerProtocolInput == "5" ]]; then
                isV2rayUnlockOutboundServerTCPText="ws"
                echo
                yellow "Please fill in the V2ray or Xray server Websocket Path that can unlock streaming media, the default is /"
                read -p "Please fill in the Websocket Path? Enter directly and the default is / , please input (do not include /):" isV2rayUnlockServerWSPathInput
                isV2rayUnlockServerWSPathInput=${isV2rayUnlockServerWSPathInput:-""}
                read -r -d '' unlockOutboundServerWebSocketSettingText << EOM
                ,
                "wsSettings": {
                    "path": "/${isV2rayUnlockServerWSPathInput}"
                }
EOM
            fi


            unlockOutboundServerXTLSFlowText=""
            isV2rayUnlockOutboundServerTLSText="tls"
            if [[ $isV2rayUnlockServerProtocolInput == "2" ]]; then
                isV2rayUnlockOutboundServerTCPText="tcp"
                isV2rayUnlockOutboundServerTLSText="xtls"

                echo
                yellow "Please select Flow in XTLS mode for V2ray or Xray server to unlock streaming"
                green " 1. VLess + TCP + XTLS (xtls-rprx-direct) recommended"
                green " 2. VLess + TCP + XTLS (xtls-rprx-splice) this item may fail to connect"
                read -p "Please select the Flow parameter? Press Enter to select 1 by default, please enter pure numbers:" isV2rayUnlockServerFlowInput
                isV2rayUnlockServerFlowInput=${isV2rayUnlockServerFlowInput:-1}

                unlockOutboundServerXTLSFlowValue="xtls-rprx-direct"
                if [[ $isV2rayUnlockServerFlowInput == "1" ]]; then
                    unlockOutboundServerXTLSFlowValue="xtls-rprx-direct"
                else
                    unlockOutboundServerXTLSFlowValue="xtls-rprx-splice"
                fi
                read -r -d '' unlockOutboundServerXTLSFlowText << EOM
                                "flow": "${unlockOutboundServerXTLSFlowValue}",
EOM
            fi


            echo
            yellow "Please fill in the V2ray or Xray server address that can unlock streaming media, such as www.example.com"
            read -p "Please fill in the address of the unlockable streaming media server? Enter directly and default to this machine, please enter:" isV2rayUnlockServerDomainInput
            isV2rayUnlockServerDomainInput=${isV2rayUnlockServerDomainInput:-127.0.0.1}

            echo
            yellow "Please fill in the V2ray or Xray server port number that can unlock streaming media, such as 443"
            read -p "Please fill in the address of the unlockable streaming media server? Enter directly and the default is 443, please input:" isV2rayUnlockServerPortInput
            isV2rayUnlockServerPortInput=${isV2rayUnlockServerPortInput:-443}

            echo
            yellow "Please fill in the user UUID of the V2ray or Xray server that can unlock streaming media, such as 4aeaf80d-f89e-46a2-b3dc-bb815eae75ba"
            read -p "Please fill in the user UUID? Enter directly and the default is 111, please input:" isV2rayUnlockServerUserIDInput
            isV2rayUnlockServerUserIDInput=${isV2rayUnlockServerUserIDInput:-111}



            read -r -d '' v2rayConfigOutboundV2rayServerInput << EOM
        {
            "tag": "V2Ray_out",
            "protocol": "${isV2rayUnlockOutboundServerProtocolText}",
            "settings": {
                "vnext": [
                    {
                        "address": "${isV2rayUnlockServerDomainInput}",
                        "port": ${isV2rayUnlockServerPortInput},
                        "users": [
                            {
                                "id": "${isV2rayUnlockServerUserIDInput}",
                                "encryption": "none",
                                ${unlockOutboundServerXTLSFlowText}
                                "level": 0
                            }
                        ]
                    }
                ]
            },
            "streamSettings": {
                "network": "${isV2rayUnlockOutboundServerTCPText}",
                "security": "${isV2rayUnlockOutboundServerTLSText}",
                "${isV2rayUnlockOutboundServerTLSText}Settings": {
                    "serverName": "${isV2rayUnlockServerDomainInput}"
                }
                ${unlockOutboundServerWebSocketSettingText}
            }
        },
EOM
}




function installV2ray(){

    v2rayPassword1=$(cat /proc/sys/kernel/random/uuid)
    v2rayPassword2=$(cat /proc/sys/kernel/random/uuid)
    v2rayPassword3=$(cat /proc/sys/kernel/random/uuid)
    v2rayPassword4=$(cat /proc/sys/kernel/random/uuid)
    v2rayPassword5=$(cat /proc/sys/kernel/random/uuid)
    v2rayPassword6=$(cat /proc/sys/kernel/random/uuid)
    v2rayPassword7=$(cat /proc/sys/kernel/random/uuid)
    v2rayPassword8=$(cat /proc/sys/kernel/random/uuid)
    v2rayPassword9=$(cat /proc/sys/kernel/random/uuid)
    v2rayPassword10=$(cat /proc/sys/kernel/random/uuid)

    echo
    if [ -f "${configV2rayPath}/xray" ] || [ -f "${configV2rayPath}/v2ray" ] || [ -f "/usr/local/bin/v2ray" ] || [ -f "/usr/bin/v2ray" ]; then
        green " =================================================="
        green "V2ray or Xray has been installed, exit the installation!"
        green " =================================================="
        exit
    fi

    green " =================================================="
    green "Start installing V2ray or Xray"
    green " =================================================="    
    echo

    if [[ ( $configV2rayWorkingMode == "trojan" ) || ( $configV2rayWorkingMode == "vlessTCPVmessWS" ) || ( $configV2rayWorkingMode == "vlessTCPWS" ) || ( $configV2rayWorkingMode == "vlessTCPWSgRPC" ) || ( $configV2rayWorkingMode == "vlessTCPWSTrojan" ) || ( $configV2rayWorkingMode == "sni" ) ]]; then
        echo
        green "Whether to use XTLS instead of TLS encryption, XTLS is a Xray-specific encryption method, which is faster and uses TLS encryption by default"
        green "Since V2ray does not support XTLS, if XTLS encryption is selected, the Xray kernel will be used for service"
        read -p "Do you want to use XTLS? Enter directly and the default is TLS encryption, please enter [y/N]:" isXrayXTLSInput
        isXrayXTLSInput=${isXrayXTLSInput:-n}
        
        if [[ $isXrayXTLSInput == [Yy] ]]; then
            promptInfoXrayName="xray"
            isXray="yes"
            configV2rayIsTlsShowInfo="xtls"
        else
            echo
            read -p "Do you want to use the Xray kernel? Press Enter and the default is the V2ray kernel, please enter [y/N]:" isV2rayOrXrayCoreInput
            isV2rayOrXrayCoreInput=${isV2rayOrXrayCoreInput:-n}

            if [[ $isV2rayOrXrayCoreInput == [Yy] ]]; then
                promptInfoXrayName="xray"
                isXray="yes"
            fi        
        fi
    else
        read -p "Do you want to use the Xray kernel? Press Enter and the default is the V2ray kernel, please enter [y/N]:" isV2rayOrXrayCoreInput
        isV2rayOrXrayCoreInput=${isV2rayOrXrayCoreInput:-n}

        if [[ $isV2rayOrXrayCoreInput == [Yy] ]]; then
            promptInfoXrayName="xray"
            isXray="yes"
        fi
    fi


    if [[ -n "${configV2rayWorkingMode}" ]]; then
    
        if [[ "${configV2rayWorkingMode}" != "sni" ]]; then
            configV2rayProtocol="vless"

            configV2rayPort=443
            configV2rayPortShowInfo=$configV2rayPort

            inputV2rayServerPort "textMainPort"
            configV2rayPort=${isV2rayUserPortInput}   
            configV2rayPortShowInfo=${isV2rayUserPortInput} 

        else
            configV2rayProtocol="vless"

            configV2rayPortShowInfo=443
            configV2rayPortGRPCShowInfo=443
        fi

    else
        echo
        read -p "Do you want to use VLESS protocol? Press Enter to default to VMess protocol, please enter [y/N]:" isV2rayUseVLessInput
        isV2rayUseVLessInput=${isV2rayUseVLessInput:-n}

        if [[ $isV2rayUseVLessInput == [Yy] ]]; then
            configV2rayProtocol="vless"
        else
            configV2rayProtocol="vmess"
        fi

        
        if [[ ${configInstallNginxMode} == "v2raySSL" ]]; then
            configV2rayPortShowInfo=443
            configV2rayPortGRPCShowInfo=443

        else
            if [[ ${configV2rayWorkingNotChangeMode} == "true" ]]; then
                configV2rayPortShowInfo=443
                configV2rayPortGRPCShowInfo=443

            else
                configV2rayIsTlsShowInfo="none"

                configV2rayPort="$(($RANDOM + 10000))"
                configV2rayPortShowInfo=$configV2rayPort

                inputV2rayServerPort "textMainPort"
                configV2rayPort=${isV2rayUserPortInput}   
                configV2rayPortShowInfo=${isV2rayUserPortInput}  

                inputV2rayStreamSettings
            fi


        fi
    fi

    if [[ "$configV2rayWorkingMode" == "sni" ]] ; then
        configSSLCertPath="${configNginxSNIDomainV2rayCertPath}"
        configSSLDomain=${configNginxSNIDomainV2ray}
    fi

    
    # add any gate
    if [[ ${configInstallNginxMode} == "v2raySSL" ]]; then
        echo
    else
        
        inputV2rayServerPort "textAdditionalPort"

        if [[ $isV2rayAdditionalPortInput == "999999" ]]; then
            v2rayConfigAdditionalPortInput=""
        else
            read -r -d '' v2rayConfigAdditionalPortInput << EOM
        ,
        {
            "listen": "0.0.0.0",
            "port": ${isV2rayAdditionalPortInput}, 
            "protocol": "dokodemo-door",
            "settings": {
                "address": "127.0.0.1",
                "port": ${configV2rayPort},
                "network": "tcp, udp",
                "followRedirect": false 
            },
            "sniffing": {
                "enabled": true,
                "destOverride": ["http", "tls"]
            }
        }     
EOM

        fi
    fi



    echo
    read -p "Do you want to customize the password of ${promptInfoXrayName}? Press Enter to create a random password by default, please enter a custom UUID password:" isV2rayUserPassordInput
    isV2rayUserPassordInput=${isV2rayUserPassordInput:-''}

    if [ -z "${isV2rayUserPassordInput}" ]; then
        isV2rayUserPassordInput=""
    else
        v2rayPassword1=${isV2rayUserPassordInput}
    fi














    echo
    echo
    isV2rayUnlockWarpModeInput="1"
    V2rayDNSUnlockText="AsIs"
    V2rayUnlockVideoSiteOutboundTagText=""
    unlockWARPServerIpInput="127.0.0.1"
    unlockWARPServerPortInput="40000"
    configWARPPortFilePath="${HOME}/wireguard/warp-port"
    configWARPPortLocalServerPort="40000"
    configWARPPortLocalServerText=""

    if [[ -f "${configWARPPortFilePath}" ]]; then
        configWARPPortLocalServerPort="$(cat ${configWARPPortFilePath})"
        configWARPPortLocalServerText="Detected that WARP Sock5 is installed on this machine, port number ${configWARPPortLocalServerPort}"
    fi

    green " =================================================="
    yellow "Do you want to unblock streaming sites like Netflix HBO Disney+"
    read -p "Would you like to unlock the streaming media website? Enter directly without unlocking by default, please enter [y/N]:" isV2rayUnlockStreamWebsiteInput
    isV2rayUnlockStreamWebsiteInput=${isV2rayUnlockStreamWebsiteInput:-n}

    if [[ $isV2rayUnlockStreamWebsiteInput == [Yy] ]]; then



    echo
    green " =================================================="
    yellow "Whether to use DNS to unblock streaming sites like Netflix HBO Disney+"
    green "For unblocking, please fill in the IP address of the DNS server that unblocks Netflix, such as 8.8.8.8"
    read -p "Do you want to use DNS to unlock streaming media? Press Enter directly without unlocking by default. To unlock, please enter the IP address of the DNS server:" isV2rayUnlockDNSInput
    isV2rayUnlockDNSInput=${isV2rayUnlockDNSInput:-n}

    V2rayDNSUnlockText="AsIs"
    v2rayConfigDNSInput=""

    if [[ "${isV2rayUnlockDNSInput}" == [Nn] ]]; then
        V2rayDNSUnlockText="AsIs"
    else
        V2rayDNSUnlockText="UseIP"
        read -r -d '' v2rayConfigDNSInput << EOM
    "dns": {
        "servers": [
            {
                "address": "${isV2rayUnlockDNSInput}",
                "port": 53,
                "domains": [
                    "geosite:netflix",
                    "geosite:youtube",
                    "geosite:bahamut",
                    "geosite:hulu",
                    "geosite:hbo",
                    "geosite:disney",
                    "geosite:bbc",
                    "geosite:4chan",
                    "geosite:fox",
                    "geosite:abema",
                    "geosite:dmm",
                    "geosite:niconico",
                    "geosite:pixiv",
                    "geosite:bilibili",
                    "geosite:viu",
                    "geosite:pornhub"
                ]
            },
        "localhost"
        ]
    }, 
EOM

    fi



    echo
    echo
    green " =================================================="
    yellow "Whether to use Cloudflare WARP to unblock streaming sites like Netflix"
    echo
    green " 1. Do not use unlock"
    green " 2. Use WARP Sock5 Proxy Unlock Recommended"
    green " 3. Unlock with WARP IPv6"
    green "4. Unlock by forwarding to an unlockable v2ray or xray server"
    echo
    green " By default, 1 is not unlocked. If you choose 2,3 to unlock, you need to install Wireguard and Cloudflare WARP, you can re-run this script to select the first installation".
    red "It is recommended to install Wireguard and Cloudflare WARP first, and then install v2ray or xray. In fact, it is no problem to install v2ray or xray first, and then install Wireguard and Cloudflare WARP"
    red "But if you install v2ray or xray first, and choose to unlock google or other streaming media, you will be temporarily unable to access google and other video sites, you need to continue to install Wireguard and Cloudflare WARP to solve it"
    echo
    read -p "Please input? Press Enter and select 1 by default to not unlock, please input pure numbers:" isV2rayUnlockWarpModeInput
    isV2rayUnlockWarpModeInput=${isV2rayUnlockWarpModeInput:-1}
    
    V2rayUnlockVideoSiteRuleText=""
    V2rayUnlockGoogleRuleText=""
    
    v2rayConfigRouteInput=""
    V2rayUnlockVideoSiteOutboundTagText=""



    if [[ $isV2rayUnlockWarpModeInput == "1" ]]; then
        echo
    else
        if [[ $isV2rayUnlockWarpModeInput == "2" ]]; then
            V2rayUnlockVideoSiteOutboundTagText="WARP_out"

            echo
            read -p "Please enter the WARP Sock5 proxy server address? Enter the default local 127.0.0.1 directly, please enter: " unlockWARPServerIpInput
            unlockWARPServerIpInput=${unlockWARPServerIpInput:-127.0.0.1}

            echo
            yellow " ${configWARPPortLocalServerText}"
            read -p "Please enter the WARP Sock5 proxy server port number? Enter the default ${configWARPPortLocalServerPort}, please enter a pure number:" unlockWARPServerPortInput
            unlockWARPServerPortInput=${unlockWARPServerPortInput:-$configWARPPortLocalServerPort}

        elif [[ $isV2rayUnlockWarpModeInput == "3" ]]; then

            V2rayUnlockVideoSiteOutboundTagText="IPv6_out"

        elif [[ $isV2rayUnlockWarpModeInput == "4" ]]; then

            echo
            green "selected 4 to unlock by forwarding to an unlockable v2ray or xray server"
            green "You can modify the v2ray or xray configuration by yourself, and add an unlockable v2ray server with the tag V2Ray_out in the outbounds field"

            V2rayUnlockVideoSiteOutboundTagText="V2Ray_out"

            inputUnlockV2rayServerInfo
        fi



        echo
        echo
        green " =================================================="
        yellow "Please select a streaming site to unblock:"
        echo
        green " 1. Do not unlock"
        green " 2. Unblock Netflix restrictions"
        green " 3. Unblock Youtube and Youtube Premium"
        green " 4. Unlock Pornhub, solve the problem that the video becomes corn and cannot be watched"
        green " 5. Unblock Netflix and Pornhub restrictions at the same time"
        green " 6. Simultaneously unblock Netflix, Youtube and Pornhub restrictions"
        green " 7. Simultaneously unblocks Netflix, Hulu, HBO, Disney and Pornhub restrictions"
        green " 8. Simultaneously unblock Netflix, Hulu, HBO, Disney, Youtube and Pornhub restrictions"
        green " 9. Unblocks all streaming media including Netflix, Youtube, Hulu, HBO, Disney, BBC, Fox, niconico, dmm, Spotify, Pornhub and more"
        echo
        read -p "Please enter the unlock option? Press Enter and select 1 by default to not unlock, please enter a pure number:" isV2rayUnlockVideoSiteInput
        isV2rayUnlockVideoSiteInput=${isV2rayUnlockVideoSiteInput:-1}

        if [[ $isV2rayUnlockVideoSiteInput == "2" ]]; then
            V2rayUnlockVideoSiteRuleText="\"geosite:netflix\""
            
        elif [[ $isV2rayUnlockVideoSiteInput == "3" ]]; then
            V2rayUnlockVideoSiteRuleText="\"geosite:youtube\""

        elif [[ $isV2rayUnlockVideoSiteInput == "4" ]]; then
            V2rayUnlockVideoSiteRuleText="\"geosite:pornhub\""

        elif [[ $isV2rayUnlockVideoSiteInput == "5" ]]; then
            V2rayUnlockVideoSiteRuleText="\"geosite:netflix\", \"geosite:pornhub\""

        elif [[ $isV2rayUnlockVideoSiteInput == "6" ]]; then
            V2rayUnlockVideoSiteRuleText="\"geosite:netflix\", \"geosite:youtube\", \"geosite:pornhub\""

        elif [[ $isV2rayUnlockVideoSiteInput == "7" ]]; then
            V2rayUnlockVideoSiteRuleText="\"geosite:netflix\", \"geosite:disney\", \"geosite:spotify\", \"geosite:hulu\", \"geosite:hbo\", \"geosite:pornhub\""

        elif [[ $isV2rayUnlockVideoSiteInput == "8" ]]; then
            V2rayUnlockVideoSiteRuleText="\"geosite:netflix\", \"geosite:disney\", \"geosite:spotify\", \"geosite:youtube\", \"geosite:hulu\", \"geosite:hbo\", \"geosite:pornhub\""

        elif [[ $isV2rayUnlockVideoSiteInput == "9" ]]; then
            V2rayUnlockVideoSiteRuleText="\"geosite:netflix\", \"geosite:disney\", \"geosite:spotify\", \"geosite:youtube\", \"geosite:bahamut\", \"geosite:hulu\", \"geosite:hbo\", \"geosite:bbc\", \"geosite:4chan\", \"geosite:fox\", \"geosite:abema\", \"geosite:dmm\", \"geosite:niconico\", \"geosite:pixiv\", \"geosite:viu\", \"geosite:pornhub\""

        fi

    fi





    echo
    yellow "A big guy has provided a V2ray server that can unblock Netflix in Singapore, and it is not guaranteed to be available all the time"
    read -p "Do you want to unlock Netflix Singapore by the mysterious force? Enter directly without unlocking by default, please enter [y/N]:" isV2rayUnlockGoNetflixInput
    isV2rayUnlockGoNetflixInput=${isV2rayUnlockGoNetflixInput:-n}

    v2rayConfigRouteGoNetflixInput=""
    v2rayConfigOutboundV2rayGoNetflixServerInput=""
    if [[ $isV2rayUnlockGoNetflixInput == [Nn] ]]; then
        echo
    else
        removeString="\"geosite:netflix\", "
        V2rayUnlockVideoSiteRuleText=${V2rayUnlockVideoSiteRuleText#"$removeString"}
        removeString2="\"geosite:disney\", "
        V2rayUnlockVideoSiteRuleText=${V2rayUnlockVideoSiteRuleText#"$removeString2"}
        read -r -d '' v2rayConfigRouteGoNetflixInput << EOM
            {
                "type": "field",
                "outboundTag": "GoNetflix",
                "domain": [ "geosite:netflix", "geosite:disney" ] 
            },
EOM

        read -r -d '' v2rayConfigOutboundV2rayGoNetflixServerInput << EOM
        {
            "tag": "GoNetflix",
            "protocol": "vmess",
            "streamSettings": {
                "network": "ws",
                "security": "tls",
                "tlsSettings": {
                    "allowInsecure": false
                },
                "wsSettings": {
                    "path": "ws"
                }
            },
            "mux": {
                "enabled": true,
                "concurrency": 8
            },
            "settings": {
                "vnext": [{
                    "address": "free-sg-01.unblocknetflix.cf",
                    "port": 443,
                    "users": [
                        { "id": "402d7490-6d4b-42d4-80ed-e681b0e6f1f9", "security": "auto", "alterId": 0 }
                    ]
                }]
            }
        },
EOM
    fi



    fi




    echo
    green " =================================================="
    yellow "Please select a way to avoid pop-up of Google reCAPTCHA captcha"
    echo
    green " 1. Do not unlock"
    green " 2. Unlock with WARP Sock5 Proxy"
    green " 3. Use WARP IPv6 unlock recommended"
    green "4. Unlock by forwarding to an unlockable v2ray or xray server"
    echo
    read -r -p "Please enter the unlock option? Press Enter and select 1 by default to not unlock, please enter a pure number:" isV2rayUnlockGoogleInput
    isV2rayUnlockGoogleInput=${isV2rayUnlockGoogleInput:-1}

    if [[ "${isV2rayUnlockWarpModeInput}" == "${isV2rayUnlockGoogleInput}" ]]; then
        V2rayUnlockVideoSiteRuleText+=", \"geosite:google\" "
        V2rayUnlockVideoSiteRuleTextFirstChar="${V2rayUnlockVideoSiteRuleText:0:1}"

        if [[ $V2rayUnlockVideoSiteRuleTextFirstChar == "," ]]; then
            V2rayUnlockVideoSiteRuleText="${V2rayUnlockVideoSiteRuleText:1}"
        fi

        # To fix a bug that is not unlocked, choose 1 bug
        if [[ -z "${V2rayUnlockVideoSiteOutboundTagText}" ]]; then
            V2rayUnlockVideoSiteOutboundTagText="IPv6_out"
            V2rayUnlockVideoSiteRuleText="\"test.com\""
        fi

        read -r -d '' v2rayConfigRouteInput << EOM
    "routing": {
        "rules": [
            ${v2rayConfigRouteGoNetflixInput}
            {
                "type": "field",
                "outboundTag": "${V2rayUnlockVideoSiteOutboundTagText}",
                "domain": [${V2rayUnlockVideoSiteRuleText}] 
            },
            {
                "type": "field",
                "outboundTag": "IPv4_out",
                "network": "udp,tcp"
            }
        ]
    },
EOM

    else
        V2rayUnlockGoogleRuleText="\"geosite:google\""

        if [[ $isV2rayUnlockGoogleInput == "2" ]]; then
            V2rayUnlockGoogleOutboundTagText="WARP_out"
            echo
            read -p "Please enter the WARP Sock5 proxy server address? Enter the default local 127.0.0.1 directly, please enter: " unlockWARPServerIpInput
            unlockWARPServerIpInput=${unlockWARPServerIpInput:-127.0.0.1}

            echo
            yellow " ${configWARPPortLocalServerText}"
            read -r -p "Please enter the WARP Sock5 proxy server port number? Enter the default ${configWARPPortLocalServerPort}, please enter a pure number:" unlockWARPServerPortInput
            unlockWARPServerPortInput=${unlockWARPServerPortInput:-$configWARPPortLocalServerPort}       

        elif [[ $isV2rayUnlockGoogleInput == "3" ]]; then
            V2rayUnlockGoogleOutboundTagText="IPv6_out"

        elif [[ $isV2rayUnlockGoogleInput == "4" ]]; then
            V2rayUnlockGoogleOutboundTagText="V2Ray_out"
            inputUnlockV2rayServerInfo
        else
            V2rayUnlockGoogleOutboundTagText="IPv4_out"
        fi

        # To fix a bug that is not unlocked, choose 1 bug
        if [[ -z "${V2rayUnlockVideoSiteOutboundTagText}" ]]; then
            V2rayUnlockVideoSiteOutboundTagText="IPv6_out"
            V2rayUnlockVideoSiteRuleText="\"xxxxx.com\""
        fi
        
        read -r -d '' v2rayConfigRouteInput << EOM
    "routing": {
        "rules": [
            ${v2rayConfigRouteGoNetflixInput}
            {
                "type": "field",
                "outboundTag": "${V2rayUnlockGoogleOutboundTagText}",
                "domain": [${V2rayUnlockGoogleRuleText}] 
            },
            {
                "type": "field",
                "outboundTag": "${V2rayUnlockVideoSiteOutboundTagText}",
                "domain": [${V2rayUnlockVideoSiteRuleText}] 
            },
            {
                "type": "field",
                "outboundTag": "IPv4_out",
                "network": "udp,tcp"
            }
        ]
    },
EOM
    fi


    read -r -d '' v2rayConfigOutboundInput << EOM
    "outbounds": [
        {
            "tag":"IPv4_out",
            "protocol": "freedom",
            "settings": {
                "domainStrategy": "${V2rayDNSUnlockText}"
            }
        },        
        {
            "tag": "blocked",
            "protocol": "blackhole",
            "settings": {}
        },
        {
            "tag":"IPv6_out",
            "protocol": "freedom",
            "settings": {
                "domainStrategy": "UseIPv6" 
            }
        },
        ${v2rayConfigOutboundV2rayServerInput}
        ${v2rayConfigOutboundV2rayGoNetflixServerInput}
        {
            "tag": "WARP_out",
            "protocol": "socks",
            "settings": {
                "servers": [
                    {
                        "address": "${unlockWARPServerIpInput}",
                        "port": ${unlockWARPServerPortInput}
                    }
                ]
            },
            "streamSettings": {
                "network": "tcp"
            }
        }
    ]

EOM












    echo
    green " =================================================="
    if [ "$isXray" = "no" ] ; then
        getTrojanAndV2rayVersion "v2ray"
        green "Ready to download and install V2ray Version: ${versionV2ray} !"
        promptInfoXrayInstall="V2ray"
        promptInfoXrayVersion=${versionV2ray}
    else
        getTrojanAndV2rayVersion "xray"
        green "Ready to download and install Xray Version: ${versionXray} !"
        promptInfoXrayInstall="Xray"
        promptInfoXrayVersion=${versionXray}
    fi
    echo


    mkdir -p ${configV2rayPath}
    cd ${configV2rayPath}
    rm -rf ${configV2rayPath}/*

    downloadV2rayXrayBin


    # Add v2ray server side configuration

    if [[ "$configV2rayWorkingMode" == "vlessTCPWSTrojan" ]]; then
        trojanPassword1=$(cat /dev/urandom | head -1 | md5sum | head -c 10)
        trojanPassword2=$(cat /dev/urandom | head -1 | md5sum | head -c 10)
        trojanPassword3=$(cat /dev/urandom | head -1 | md5sum | head -c 10)
        trojanPassword4=$(cat /dev/urandom | head -1 | md5sum | head -c 10)
        trojanPassword5=$(cat /dev/urandom | head -1 | md5sum | head -c 10)
        trojanPassword6=$(cat /dev/urandom | head -1 | md5sum | head -c 10)
        trojanPassword7=$(cat /dev/urandom | head -1 | md5sum | head -c 10)
        trojanPassword8=$(cat /dev/urandom | head -1 | md5sum | head -c 10)
        trojanPassword9=$(cat /dev/urandom | head -1 | md5sum | head -c 10)
        trojanPassword10=$(cat /dev/urandom | head -1 | md5sum | head -c 10)

        echo
        yellow "Please enter a prefix for the trojan password? (several random passwords and passwords with this prefix will be generated)"
        read -p "Please enter the prefix of the password, press Enter to generate a random prefix by default:" configTrojanPasswordPrefixInput
        configTrojanPasswordPrefixInput=${configTrojanPasswordPrefixInput:-${configTrojanPasswordPrefixInputDefault}}
    fi

    if [ "${isTrojanMultiPassword}" = "no" ] ; then
    read -r -d '' v2rayConfigUserpasswordTrojanInput << EOM
                    {
                        "password": "${trojanPassword1}", "level": 0, "email": "password111@gmail.com"
                    },
                    {
                        "password": "${trojanPassword2}", "level": 0, "email": "password112@gmail.com"
                    },
                    {
                        "password": "${trojanPassword3}", "level": 0, "email": "password113@gmail.com"
                    },
                    {
                        "password": "${trojanPassword4}", "level": 0, "email": "password114@gmail.com"
                    },
                    {
                        "password": "${trojanPassword5}", "level": 0, "email": "password115@gmail.com"
                    },
                    {
                        "password": "${trojanPassword6}", "level": 0, "email": "password116@gmail.com"
                    },
                    {
                        "password": "${trojanPassword7}", "level": 0, "email": "password117@gmail.com"
                    },
                    {
                        "password": "${trojanPassword8}", "level": 0, "email": "password118@gmail.com"
                    },
                    {
                        "password": "${trojanPassword9}", "level": 0, "email": "password119@gmail.com"
                    },
                    {
                        "password": "${trojanPassword10}", "level": 0, "email": "password120@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202001", "level": 0, "email": "password201@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202002", "level": 0, "email": "password202@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202003", "level": 0, "email": "password203@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202004", "level": 0, "email": "password204@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202005", "level": 0, "email": "password205@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202006", "level": 0, "email": "password206@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202007", "level": 0, "email": "password207@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202008", "level": 0, "email": "password208@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202009", "level": 0, "email": "password209@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202010", "level": 0, "email": "password210@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202011", "level": 0, "email": "password211@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202012", "level": 0, "email": "password212@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202013", "level": 0, "email": "password213@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202014", "level": 0, "email": "password214@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202015", "level": 0, "email": "password215@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202016", "level": 0, "email": "password216@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202017", "level": 0, "email": "password217@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202018", "level": 0, "email": "password218@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202019", "level": 0, "email": "password219@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202020", "level": 0, "email": "password220@gmail.com"
                    }
EOM
    else

    read -r -d '' v2rayConfigUserpasswordTrojanInput << EOM
                    {
                        "password": "${trojanPassword1}", "level": 0, "email": "password111@gmail.com"
                    },
                    {
                        "password": "${trojanPassword2}", "level": 0, "email": "password112@gmail.com"
                    },
                    {
                        "password": "${trojanPassword3}", "level": 0, "email": "password113@gmail.com"
                    },
                    {
                        "password": "${trojanPassword4}", "level": 0, "email": "password114@gmail.com"
                    },
                    {
                        "password": "${trojanPassword5}", "level": 0, "email": "password115@gmail.com"
                    },
                    {
                        "password": "${trojanPassword6}", "level": 0, "email": "password116@gmail.com"
                    },
                    {
                        "password": "${trojanPassword7}", "level": 0, "email": "password117@gmail.com"
                    },
                    {
                        "password": "${trojanPassword8}", "level": 0, "email": "password118@gmail.com"
                    },
                    {
                        "password": "${trojanPassword9}", "level": 0, "email": "password119@gmail.com"
                    },
                    {
                        "password": "${trojanPassword10}", "level": 0, "email": "password120@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202000", "level": 0, "email": "password200@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202001", "level": 0, "email": "password201@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202002", "level": 0, "email": "password202@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202003", "level": 0, "email": "password203@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202004", "level": 0, "email": "password204@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202005", "level": 0, "email": "password205@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202006", "level": 0, "email": "password206@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202007", "level": 0, "email": "password207@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202008", "level": 0, "email": "password208@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202009", "level": 0, "email": "password209@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202010", "level": 0, "email": "password210@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202011", "level": 0, "email": "password211@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202012", "level": 0, "email": "password212@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202013", "level": 0, "email": "password213@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202014", "level": 0, "email": "password214@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202015", "level": 0, "email": "password215@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202016", "level": 0, "email": "password216@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202017", "level": 0, "email": "password217@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202018", "level": 0, "email": "password218@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202019", "level": 0, "email": "password219@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202020", "level": 0, "email": "password220@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202021", "level": 0, "email": "password221@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202022", "level": 0, "email": "password222@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202023", "level": 0, "email": "password223@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202024", "level": 0, "email": "password224@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202025", "level": 0, "email": "password225@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202026", "level": 0, "email": "password226@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202027", "level": 0, "email": "password227@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202028", "level": 0, "email": "password228@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202029", "level": 0, "email": "password229@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202030", "level": 0, "email": "password230@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202031", "level": 0, "email": "password231@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202032", "level": 0, "email": "password232@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202033", "level": 0, "email": "password233@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202034", "level": 0, "email": "password234@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202035", "level": 0, "email": "password235@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202036", "level": 0, "email": "password236@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202037", "level": 0, "email": "password237@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202038", "level": 0, "email": "password238@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202039", "level": 0, "email": "password239@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202040", "level": 0, "email": "password240@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202041", "level": 0, "email": "password241@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202042", "level": 0, "email": "password242@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202043", "level": 0, "email": "password243@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202044", "level": 0, "email": "password244@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202045", "level": 0, "email": "password245@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202046", "level": 0, "email": "password246@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202047", "level": 0, "email": "password247@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202048", "level": 0, "email": "password248@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202049", "level": 0, "email": "password249@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202050", "level": 0, "email": "password250@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202051", "level": 0, "email": "password251@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202052", "level": 0, "email": "password252@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202053", "level": 0, "email": "password253@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202054", "level": 0, "email": "password254@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202055", "level": 0, "email": "password255@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202056", "level": 0, "email": "password256@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202057", "level": 0, "email": "password257@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202058", "level": 0, "email": "password258@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202059", "level": 0, "email": "password259@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202060", "level": 0, "email": "password260@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202061", "level": 0, "email": "password261@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202062", "level": 0, "email": "password262@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202063", "level": 0, "email": "password263@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202064", "level": 0, "email": "password264@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202065", "level": 0, "email": "password265@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202066", "level": 0, "email": "password266@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202067", "level": 0, "email": "password267@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202068", "level": 0, "email": "password268@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202069", "level": 0, "email": "password269@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202070", "level": 0, "email": "password270@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202071", "level": 0, "email": "password271@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202072", "level": 0, "email": "password272@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202073", "level": 0, "email": "password273@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202074", "level": 0, "email": "password274@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202075", "level": 0, "email": "password275@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202076", "level": 0, "email": "password276@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202077", "level": 0, "email": "password277@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202078", "level": 0, "email": "password278@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202079", "level": 0, "email": "password279@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202080", "level": 0, "email": "password280@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202081", "level": 0, "email": "password281@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202082", "level": 0, "email": "password282@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202083", "level": 0, "email": "password283@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202084", "level": 0, "email": "password284@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202085", "level": 0, "email": "password285@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202086", "level": 0, "email": "password286@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202087", "level": 0, "email": "password287@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202088", "level": 0, "email": "password288@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202089", "level": 0, "email": "password289@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202090", "level": 0, "email": "password290@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202091", "level": 0, "email": "password291@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202092", "level": 0, "email": "password292@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202093", "level": 0, "email": "password293@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202094", "level": 0, "email": "password294@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202095", "level": 0, "email": "password295@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202096", "level": 0, "email": "password296@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202097", "level": 0, "email": "password297@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202098", "level": 0, "email": "password298@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202099", "level": 0, "email": "password299@gmail.com"
                    }

EOM
    fi

    if [[ "${configV2rayIsTlsShowInfo}" == "xtls"  ]]; then
    read -r -d '' v2rayConfigUserpasswordInput << EOM
                    {
                        "id": "${v2rayPassword1}", "flow": "xtls-rprx-direct", "level": 0, "email": "password11@gmail.com"
                    },
                    {
                        "id": "${v2rayPassword2}", "flow": "xtls-rprx-direct", "level": 0, "email": "password12@gmail.com"
                    },
                    {
                        "id": "${v2rayPassword3}", "flow": "xtls-rprx-direct", "level": 0, "email": "password13@gmail.com"
                    },
                    {
                        "id": "${v2rayPassword4}", "flow": "xtls-rprx-direct", "level": 0, "email": "password14@gmail.com"
                    },
                    {
                        "id": "${v2rayPassword5}", "flow": "xtls-rprx-direct", "level": 0, "email": "password15@gmail.com"
                    },
                    {
                        "id": "${v2rayPassword6}", "flow": "xtls-rprx-direct", "level": 0, "email": "password16@gmail.com"
                    },
                    {
                        "id": "${v2rayPassword7}", "flow": "xtls-rprx-direct", "level": 0, "email": "password17@gmail.com"
                    },
                    {
                        "id": "${v2rayPassword8}", "flow": "xtls-rprx-direct", "level": 0, "email": "password18@gmail.com"
                    },
                    {
                        "id": "${v2rayPassword9}", "flow": "xtls-rprx-direct", "level": 0, "email": "password19@gmail.com"
                    },
                    {
                        "id": "${v2rayPassword10}", "flow": "xtls-rprx-direct", "level": 0, "email": "password20@gmail.com"
                    }
EOM

    else
    read -r -d '' v2rayConfigUserpasswordInput << EOM
                    {
                        "id": "${v2rayPassword1}", "level": 0, "email": "password11@gmail.com"
                    },
                    {
                        "id": "${v2rayPassword2}", "level": 0, "email": "password12@gmail.com"
                    },
                    {
                        "id": "${v2rayPassword3}", "level": 0, "email": "password13@gmail.com"
                    },
                    {
                        "id": "${v2rayPassword4}", "level": 0, "email": "password14@gmail.com"
                    },
                    {
                        "id": "${v2rayPassword5}", "level": 0, "email": "password15@gmail.com"
                    },
                    {
                        "id": "${v2rayPassword6}", "level": 0, "email": "password16@gmail.com"
                    },
                    {
                        "id": "${v2rayPassword7}", "level": 0, "email": "password17@gmail.com"
                    },
                    {
                        "id": "${v2rayPassword8}", "level": 0, "email": "password18@gmail.com"
                    },
                    {
                        "id": "${v2rayPassword9}", "level": 0, "email": "password19@gmail.com"
                    },
                    {
                        "id": "${v2rayPassword10}", "level": 0, "email": "password20@gmail.com"
                    }
EOM

    fi










    v2rayConfigInboundInput=""

    if [[ "${configV2rayStreamSetting}" == "grpc" ]]; then

        read -r -d '' v2rayConfigInboundInput << EOM

    "inbounds": [
        {
            "port": ${configV2rayGRPCPort},
            "protocol": "${configV2rayProtocol}",
            "settings": {
                "clients": [
                    ${v2rayConfigUserpasswordInput}
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "grpc",
                "security": "none",
                "grpcSettings": {
                    "serviceName": "${configV2rayGRPCServiceName}" 
                }
            }
        }
        ${v2rayConfigAdditionalPortInput}
    ],

EOM

    elif [[ "${configV2rayStreamSetting}" == "ws" ]]; then

        read -r -d '' v2rayConfigInboundInput << EOM

    "inbounds": [
        {
            "port": ${configV2rayPort},
            "protocol": "${configV2rayProtocol}",
            "settings": {
                "clients": [
                    ${v2rayConfigUserpasswordInput}
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "ws",
                "security": "none",
                "wsSettings": {
                    "path": "/${configV2rayWebSocketPath}"
                }
            }
        }
        ${v2rayConfigAdditionalPortInput}
    ],

EOM


    elif [[ "${configV2rayStreamSetting}" == "wsgrpc" ]]; then

        read -r -d '' v2rayConfigInboundInput << EOM

    "inbounds": [
        {
            "port": ${configV2rayPort},
            "protocol": "${configV2rayProtocol}",
            "settings": {
                "clients": [
                    ${v2rayConfigUserpasswordInput}
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "ws",
                "security": "none",
                "wsSettings": {
                    "path": "/${configV2rayWebSocketPath}"
                }
            }
        },
        {
            "port": ${configV2rayGRPCPort},
            "protocol": "${configV2rayProtocol}",
            "settings": {
                "clients": [
                    ${v2rayConfigUserpasswordInput}
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "grpc",
                "security": "none",
                "grpcSettings": {
                    "serviceName": "${configV2rayGRPCServiceName}" 
                }
            }
        }
        ${v2rayConfigAdditionalPortInput}
    ],

EOM

    elif [[ "${configV2rayStreamSetting}" == "tcp" ]]; then

        read -r -d '' v2rayConfigInboundInput << EOM

    "inbounds": [
        {
            "port": ${configV2rayPort},
            "protocol": "${configV2rayProtocol}",
            "settings": {
                "clients": [
                    ${v2rayConfigUserpasswordInput}
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "tcp",
                "security": "none",
                "tcpSettings": {
                    "acceptProxyProtocol": false,
                    "header": {
                        "type": "none"
                    }
                }
            }
        }
        ${v2rayConfigAdditionalPortInput}
    ],

EOM


    elif [[ "${configV2rayStreamSetting}" == "kcp" ]]; then

        read -r -d '' v2rayConfigInboundInput << EOM

    "inbounds": [
        {
            "port": ${configV2rayPort},
            "protocol": "${configV2rayProtocol}",
            "settings": {
                "clients": [
                    ${v2rayConfigUserpasswordInput}
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "kcp",
                "security": "none",
                "kcpSettings": {
                    "seed": "${configV2rayKCPSeedPassword}"
                }
            }
        }
        ${v2rayConfigAdditionalPortInput}
    ],

EOM

    elif [[ "${configV2rayStreamSetting}" == "h2" ]]; then

        read -r -d '' v2rayConfigInboundInput << EOM

    "inbounds": [
        {
            "port": ${configV2rayPort},
            "protocol": "${configV2rayProtocol}",
            "settings": {
                "clients": [
                    ${v2rayConfigUserpasswordInput}
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "h2",
                "security": "none",
                "httpSettings": {
                    "path": "/${configV2rayWebSocketPath}"
                }            
            }
        }
        ${v2rayConfigAdditionalPortInput}
    ],

EOM

    elif [[ "${configV2rayStreamSetting}" == "quic" ]]; then

        read -r -d '' v2rayConfigInboundInput << EOM

    "inbounds": [
        {
            "port": ${configV2rayPort},
            "protocol": "${configV2rayProtocol}",
            "settings": {
                "clients": [
                    ${v2rayConfigUserpasswordInput}
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "quic",
                "security": "none",
                "quicSettings": {
                    "security": "aes-128-gcm",
                    "key": "${configV2rayKCPSeedPassword}",
                    "header": {
                        "type": "none"
                    }
                }
            }
        }
        ${v2rayConfigAdditionalPortInput}
    ],

EOM

    fi









    if [[ "$configV2rayWorkingMode" == "vlessTCPVmessWS" ]]; then

        read -r -d '' v2rayConfigInboundInput << EOM
    "inbounds": [
        {
            "port": ${configV2rayPort},
            "protocol": "${configV2rayProtocol}",
            "settings": {
                "clients": [
                    ${v2rayConfigUserpasswordInput}
                ],
                "decryption": "none",
                "fallbacks": [
                    {
                        "dest": 80
                    },
                    {
                        "path": "/${configV2rayWebSocketPath}",
                        "dest": ${configV2rayVmesWSPort},
                        "xver": 1
                    },
                    {
                        "path": "/tcp${configV2rayWebSocketPath}",
                        "dest": ${configV2rayVmessTCPPort},
                        "xver": 1
                    }
                ]
            },
            "streamSettings": {
                "network": "tcp",
                "security": "${configV2rayIsTlsShowInfo}",
                "${configV2rayIsTlsShowInfo}Settings": {
                    "alpn": [
                        "http/1.1"
                    ],
                    "certificates": [
                        {
                            "certificateFile": "${configSSLCertPath}/$configSSLCertFullchainFilename",
                            "keyFile": "${configSSLCertPath}/$configSSLCertKeyFilename"
                        }
                    ]
                }
            }
        },
        {
            "port": ${configV2rayVmesWSPort},
            "listen": "127.0.0.1",
            "protocol": "vmess",
            "settings": {
                "clients": [
                    ${v2rayConfigUserpasswordInput}
                ]
            },
            "streamSettings": {
                "network": "ws",
                "security": "none",
                "wsSettings": {
                    "acceptProxyProtocol": true,
                    "path": "/${configV2rayWebSocketPath}" 
                }
            }
        },
        {
            "port": ${configV2rayVmessTCPPort},
            "listen": "127.0.0.1",
            "protocol": "vmess",
            "settings": {
                "clients": [
                    ${v2rayConfigUserpasswordInput}
                ]
            },
            "streamSettings": {
                "network": "tcp",
                "security": "none",
                "tcpSettings": {
                    "acceptProxyProtocol": true,
                    "header": {
                        "type": "http",
                        "request": {
                            "path": [
                                "/tcp${configV2rayWebSocketPath}"
                            ]
                        }
                    }
                }
            }
        }
        ${v2rayConfigAdditionalPortInput}
    ],
EOM


    elif [[ "$configV2rayWorkingMode" == "vlessgRPC" ]]; then

        read -r -d '' v2rayConfigInboundInput << EOM
    "inbounds": [
        {
            "port": ${configV2rayPort},
            "protocol": "${configV2rayProtocol}",
            "settings": {
                "clients": [
                    ${v2rayConfigUserpasswordInput}
                ],
                "decryption": "none",
                "fallbacks": [
                    {
                        "dest": 80
                    }
                ]
            },
            "streamSettings": {
                "network": "grpc",
                "security": "tls",
                "tlsSettings": {
                    "alpn": [
                        "h2", 
                        "http/1.1"
                    ],
                    "certificates": [
                        {
                            "certificateFile": "${configSSLCertPath}/$configSSLCertFullchainFilename",
                            "keyFile": "${configSSLCertPath}/$configSSLCertKeyFilename"
                        }
                    ]
                },
                "grpcSettings": {
                    "serviceName": "${configV2rayGRPCServiceName}"
                }
            }
        }
        ${v2rayConfigAdditionalPortInput}
    ],
EOM


    elif [[ $configV2rayWorkingMode == "vlessTCPWS" ]]; then

        read -r -d '' v2rayConfigInboundInput << EOM
    "inbounds": [
        {
            "port": ${configV2rayPort},
            "protocol": "${configV2rayProtocol}",
            "settings": {
                "clients": [
                    ${v2rayConfigUserpasswordInput}
                ],
                "decryption": "none",
                "fallbacks": [
                    {
                        "dest": 80
                    },
                    {
                        "path": "/${configV2rayWebSocketPath}",
                        "dest": ${configV2rayVmesWSPort},
                        "xver": 1
                    }
                ]
            },
            "streamSettings": {
                "network": "tcp",
                "security": "${configV2rayIsTlsShowInfo}",
                "${configV2rayIsTlsShowInfo}Settings": {
                    "alpn": [
                        "http/1.1"
                    ],
                    "certificates": [
                        {
                            "certificateFile": "${configSSLCertPath}/$configSSLCertFullchainFilename",
                            "keyFile": "${configSSLCertPath}/$configSSLCertKeyFilename"
                        }
                    ]
                }
            }
        },
        {
            "port": ${configV2rayVmesWSPort},
            "listen": "127.0.0.1",
            "protocol": "vless",
            "settings": {
                "clients": [
                    ${v2rayConfigUserpasswordInput}
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "ws",
                "security": "none",
                "wsSettings": {
                    "acceptProxyProtocol": true,
                    "path": "/${configV2rayWebSocketPath}" 
                }
            }
        }
        ${v2rayConfigAdditionalPortInput}
    ],
EOM


    elif [[ "$configV2rayWorkingMode" == "vlessTCPWSgRPC" || "$configV2rayWorkingMode" == "sni" ]]; then

        read -r -d '' v2rayConfigInboundInput << EOM
    "inbounds": [
        {
            "port": ${configV2rayPort},
            "protocol": "${configV2rayProtocol}",
            "settings": {
                "clients": [
                    ${v2rayConfigUserpasswordInput}
                ],
                "decryption": "none",
                "fallbacks": [
                    {
                        "dest": 80
                    },
                    {
                        "path": "/${configV2rayWebSocketPath}",
                        "dest": ${configV2rayVmesWSPort},
                        "xver": 1
                    },
                    {
                        "path": "/${configV2rayGRPCServiceName}",
                        "dest": ${configV2rayGRPCPort},
                        "xver": 1
                    }
                ]
            },
            "streamSettings": {
                "network": "tcp",
                "security": "${configV2rayIsTlsShowInfo}",
                "${configV2rayIsTlsShowInfo}Settings": {
                    "alpn": [
                        "http/1.1"
                    ],
                    "certificates": [
                        {
                            "certificateFile": "${configSSLCertPath}/$configSSLCertFullchainFilename",
                            "keyFile": "${configSSLCertPath}/$configSSLCertKeyFilename"
                        }
                    ]
                }
            }
        },
        {
            "port": ${configV2rayVmesWSPort},
            "listen": "127.0.0.1",
            "protocol": "vless",
            "settings": {
                "clients": [
                    ${v2rayConfigUserpasswordInput}
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "ws",
                "security": "none",
                "wsSettings": {
                    "acceptProxyProtocol": true,
                    "path": "/${configV2rayWebSocketPath}" 
                }
            }
        },
        {
            "port": ${configV2rayGRPCPort},
            "protocol": "vless",
            "settings": {
                "clients": [
                    ${v2rayConfigUserpasswordInput}
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "grpc",
                "security": "none",
                "grpcSettings": {
                    "serviceName": "${configV2rayGRPCServiceName}"
                }
            }
        }
        ${v2rayConfigAdditionalPortInput}
    ],
EOM


    elif [[  $configV2rayWorkingMode == "vlessTCPWSTrojan" ]]; then

        read -r -d '' v2rayConfigInboundInput << EOM
    "inbounds": [
        {
            "port": ${configV2rayPort},
            "protocol": "${configV2rayProtocol}",
            "settings": {
                "clients": [
                    ${v2rayConfigUserpasswordInput}
                ],
                "decryption": "none",
                "fallbacks": [
                    {
                        "dest": ${configV2rayTrojanPort},
                        "xver": 1
                    },
                    {
                        "path": "/${configV2rayWebSocketPath}",
                        "dest": ${configV2rayVmesWSPort},
                        "xver": 1
                    }
                ]
            },
            "streamSettings": {
                "network": "tcp",
                "security": "${configV2rayIsTlsShowInfo}",
                "${configV2rayIsTlsShowInfo}Settings": {
                    "alpn": [
                        "http/1.1"
                    ],
                    "certificates": [
                        {
                            "certificateFile": "${configSSLCertPath}/$configSSLCertFullchainFilename",
                            "keyFile": "${configSSLCertPath}/$configSSLCertKeyFilename"
                        }
                    ]
                }
            }
        },
        {
            "port": ${configV2rayTrojanPort},
            "listen": "127.0.0.1",
            "protocol": "trojan",
            "settings": {
                "clients": [
                    ${v2rayConfigUserpasswordTrojanInput}
                ],
                "fallbacks": [
                    {
                        "dest": 80 
                    }
                ]
            },
            "streamSettings": {
                "network": "tcp",
                "security": "none",
                "tcpSettings": {
                    "acceptProxyProtocol": true
                }
            }
        },
        {
            "port": ${configV2rayVmesWSPort},
            "listen": "127.0.0.1",
            "protocol": "vless",
            "settings": {
                "clients": [
                    ${v2rayConfigUserpasswordInput}
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "ws",
                "security": "none",
                "wsSettings": {
                    "acceptProxyProtocol": true,
                    "path": "/${configV2rayWebSocketPath}" 
                }
            }
        }
        ${v2rayConfigAdditionalPortInput}
    ],
EOM



    elif [[ $configV2rayWorkingMode == "trojan" ]]; then
read -r -d '' v2rayConfigInboundInput << EOM
    "inbounds": [
        {
            "port": ${configV2rayPort},
            "protocol": "${configV2rayProtocol}",
            "settings": {
                "clients": [
                    ${v2rayConfigUserpasswordInput}
                ],
                "decryption": "none",
                "fallbacks": [
                    {
                        "dest": 80
                    },
                    {
                        "path": "/${configTrojanGoWebSocketPath}",
                        "dest": ${configV2rayTrojanPort},
                        "xver": 1
                    },
                    {
                        "path": "/${configV2rayWebSocketPath}",
                        "dest": ${configV2rayVmesWSPort},
                        "xver": 1
                    }
                ]
            },
            "streamSettings": {
                "network": "tcp",
                "security": "${configV2rayIsTlsShowInfo}",
                "${configV2rayIsTlsShowInfo}Settings": {
                    "alpn": [
                        "http/1.1"
                    ],
                    "certificates": [
                        {
                            "certificateFile": "${configSSLCertPath}/$configSSLCertFullchainFilename",
                            "keyFile": "${configSSLCertPath}/$configSSLCertKeyFilename"
                        }
                    ]
                }
            }
        },
        {
            "port": ${configV2rayVmesWSPort},
            "listen": "127.0.0.1",
            "protocol": "vless",
            "settings": {
                "clients": [
                    ${v2rayConfigUserpasswordInput}
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "ws",
                "security": "none",
                "wsSettings": {
                    "acceptProxyProtocol": true,
                    "path": "/${configV2rayWebSocketPath}" 
                }
            }
        }
        ${v2rayConfigAdditionalPortInput}
    ],
EOM

    fi



    cat > ${configV2rayPath}/config.json <<-EOF
{
    "log" : {
        "access": "${configV2rayAccessLogFilePath}",
        "error": "${configV2rayErrorLogFilePath}",
        "loglevel": "warning"
    },
    ${v2rayConfigDNSInput}
    ${v2rayConfigInboundInput}
    ${v2rayConfigRouteInput}
    ${v2rayConfigOutboundInput}
}
EOF















    # Add V2ray startup script
    if [ "$isXray" = "no" ] ; then
    
        cat > ${osSystemMdPath}${promptInfoXrayName}${promptInfoXrayNameServiceName}.service <<-EOF
[Unit]
Description=V2Ray
Documentation=https://www.v2fly.org/
After=network.target nss-lookup.target

[Service]
Type=simple
# This service runs as root. You may consider to run it as another user for security concerns.
# By uncommenting User=nobody and commenting out User=root, the service will run as user nobody.
# More discussion at https://github.com/v2ray/v2ray-core/issues/1011
User=root
#User=nobody
#CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=${configV2rayPath}/v2ray -config ${configV2rayPath}/config.json
Restart=on-failure
RestartPreventExitStatus=23

[Install]
WantedBy=multi-user.target
EOF
    else
        cat > ${osSystemMdPath}${promptInfoXrayName}${promptInfoXrayNameServiceName}.service <<-EOF
[Unit]
Description=Xray
Documentation=https://www.v2fly.org/
After=network.target nss-lookup.target

[Service]
Type=simple
# This service runs as root. You may consider to run it as another user for security concerns.
# By uncommenting User=nobody and commenting out User=root, the service will run as user nobody.
# More discussion at https://github.com/v2ray/v2ray-core/issues/1011
User=root
#User=nobody
#CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=${configV2rayPath}/xray run -config ${configV2rayPath}/config.json
Restart=on-failure
RestartPreventExitStatus=23

[Install]
WantedBy=multi-user.target
EOF
    fi

    ${sudoCmd} chmod +x ${configV2rayPath}/${promptInfoXrayName}
    ${sudoCmd} chmod +x ${osSystemMdPath}${promptInfoXrayName}${promptInfoXrayNameServiceName}.service
    ${sudoCmd} systemctl daemon-reload
    
    ${sudoCmd} systemctl enable ${promptInfoXrayName}${promptInfoXrayNameServiceName}.service
    ${sudoCmd} systemctl restart ${promptInfoXrayName}${promptInfoXrayNameServiceName}.service








    generateVLessImportLink

    if [[ "${configV2rayStreamSetting}" == "tcp" ]]; then
        cat > ${configV2rayPath}/clientConfig.json <<-EOF
========== ${promptInfoXrayInstall} Client Configuration Parameters =============
{
    Protocol: ${configV2rayProtocol},
    Address: ${configSSLDomain},
    Port: ${configV2rayPortShowInfo},
    uuid: ${v2rayPassword1},
    Additional id/AlterID: 0, // AlterID, Vmess please fill in 0, if it is Vless protocol, this item is not required
    Encryption method: aes-128-gcm, // if it is Vless protocol, it is none
    Transmission protocol: tcp,
    The underlying transport protocol: ${configV2rayIsTlsShowInfo},
    Aliases: give yourself an arbitrary name
}

Import link in Vmess Base64 format:
${v2rayVmessLinkQR1}

Import link Vless format:
${v2rayVlessLinkQR1}

EOF

    elif [[ "${configV2rayStreamSetting}" == "kcp" ]]; then
        cat > ${configV2rayPath}/clientConfig.json <<-EOF
========== ${promptInfoXrayInstall} Client Configuration Parameters =============
{
    Protocol: ${configV2rayProtocol},
    Address: ${configSSLDomain},
    Port: ${configV2rayPortShowInfo},
    uuid: ${v2rayPassword1},
    Additional id/AlterID: 0, // AlterID, Vmess please fill in 0, if it is Vless protocol, this item is not required
    Encryption method: aes-128-gcm, // if it is Vless protocol, it is none
    Transport protocol: kcp,
    The underlying transport protocol: ${configV2rayIsTlsShowInfo},
    seed obfuscated password: "${configV2rayKCPSeedPassword}",
    Aliases: give yourself an arbitrary name
}

Import link in Vmess Base64 format:
${v2rayVmessLinkQR1}

Import link Vless format:
${v2rayVlessLinkQR1}


EOF

    elif [[ "${configV2rayStreamSetting}" == "h2" ]]; then
        cat > ${configV2rayPath}/clientConfig.json <<-EOF
========== ${promptInfoXrayInstall} Client Configuration Parameters =============
{
    Protocol: ${configV2rayProtocol},
    Address: ${configSSLDomain},
    Port: ${configV2rayPortShowInfo},
    uuid: ${v2rayPassword1},
    Additional id/AlterID: 0, // AlterID, Vmess please fill in 0, if it is Vless protocol, this item is not required
    Encryption method: aes-128-gcm, // if it is Vless protocol, it is none
    Transmission protocol: h2,
    The underlying transport protocol: ${configV2rayIsTlsShowInfo},
    path:/${configV2rayWebSocketPath},
    Aliases: give yourself an arbitrary name
}

Import link in Vmess Base64 format:
${v2rayVmessLinkQR1}

Import link Vless format:
${v2rayVlessLinkQR1}

EOF

    elif [[ "${configV2rayStreamSetting}" == "quic" ]]; then
        cat > ${configV2rayPath}/clientConfig.json <<-EOF
========== ${promptInfoXrayInstall} Client Configuration Parameters =============
{
    Protocol: ${configV2rayProtocol},
    Address: ${configSSLDomain},
    Port: ${configV2rayPortShowInfo},
    uuid: ${v2rayPassword1},
    Additional id/AlterID: 0, // AlterID, Vmess please fill in 0, if it is Vless protocol, this item is not required
    Encryption method: aes-128-gcm, // if it is Vless protocol, it is none
    Transport protocol: quic,
    The underlying transport protocol: ${configV2rayIsTlsShowInfo},
    This security: none
    key The key used for encryption: "${configV2rayKCPSeedPassword}",
    Aliases: give yourself an arbitrary name
}

Import link in Vmess Base64 format:
${v2rayVmessLinkQR1}

Import link Vless format:
${v2rayVlessLinkQR1}

EOF


    elif [[ "${configV2rayStreamSetting}" == "grpc" ]]; then
        cat > ${configV2rayPath}/clientConfig.json <<-EOF
========== ${promptInfoXrayInstall} Client Configuration Parameters =============
{
    Protocol: ${configV2rayProtocol},
    Address: ${configSSLDomain},
    Port: ${configV2rayPortGRPCShowInfo},
    uuid: ${v2rayPassword1},
    Additional id/AlterID: 0, // AlterID, Vmess please fill in 0, if it is Vless protocol, this item is not required
    Encryption method: aes-128-gcm, // if it is Vless protocol, it is none
    Transport protocol: gRPC,
    gRPC serviceName: ${configV2rayGRPCServiceName}, // serviceName cannot have/
    The underlying transport protocol: ${configV2rayIsTlsShowInfo},
    Aliases: give yourself an arbitrary name
}

Import link in Vmess Base64 format:
${v2rayVmessLinkQR1}

Import link Vless format:
${v2rayVlessLinkQR1}

EOF

    elif [[ "${configV2rayStreamSetting}" == "wsgrpc" ]]; then
        cat > ${configV2rayPath}/clientConfig.json <<-EOF
========== ${promptInfoXrayInstall} Client Configuration Parameters =============
{
    Protocol: ${configV2rayProtocol},
    Address: ${configSSLDomain},
    Port: ${configV2rayPortShowInfo},
    uuid: ${v2rayPassword1},
    Additional id/AlterID: 0, // AlterID, Vmess please fill in 0, if it is Vless protocol, this item is not required
    Encryption method: aes-128-gcm, // if it is Vless protocol, it is none
    Transport protocol: websocket,
    websocket path:/${configV2rayWebSocketPath},
    The underlying transport protocol: ${configV2rayIsTlsShowInfo},
    Aliases: give yourself an arbitrary name
}

Import link in Vmess Base64 format:
${v2rayVmessLinkQR1}

Import link Vless format:
${v2rayVlessLinkQR1}


=========== ${promptInfoXrayInstall} gRPC client configuration parameters =============
{
    Protocol: ${configV2rayProtocol},
    Address: ${configSSLDomain},
    Port: ${configV2rayPortGRPCShowInfo},
    uuid: ${v2rayPassword1},
    Additional id/AlterID: 0, // AlterID, Vmess please fill in 0, if it is Vless protocol, this item is not required
    Encryption method: aes-128-gcm, // if it is Vless protocol, it is none
    Transport protocol: gRPC,
    gRPC serviceName: ${configV2rayGRPCServiceName}, // serviceName cannot have/
    The underlying transport protocol: ${configV2rayIsTlsShowInfo},
    Aliases: give yourself an arbitrary name
}

Import link in Vmess Base64 format:
${v2rayVmessLinkQR2}

Import link Vless format:
${v2rayVlessLinkQR2}

EOF

    elif [[ "${configV2rayStreamSetting}" == "ws" ]]; then
        cat > ${configV2rayPath}/clientConfig.json <<-EOF
========== ${promptInfoXrayInstall} Client Configuration Parameters =============
{
    Protocol: ${configV2rayProtocol},
    Address: ${configSSLDomain},
    Port: ${configV2rayPortShowInfo},
    uuid: ${v2rayPassword1},
    Additional id/AlterID: 0, // AlterID, Vmess please fill in 0, if it is Vless protocol, this item is not required
    Encryption method: aes-128-gcm, // if it is Vless protocol, it is none
    Transport protocol: websocket,
    websocket path:/${configV2rayWebSocketPath},
    The underlying transport protocol: ${configV2rayIsTlsShowInfo},
    Aliases: give yourself an arbitrary name
}

Import link in Vmess Base64 format:
${v2rayVmessLinkQR1}

Import link Vless format:
${v2rayVlessLinkQR1}

EOF

    fi





    if [[ "$configV2rayWorkingMode" == "vlessTCPVmessWS" ]]; then

        cat > ${configV2rayPath}/clientConfig.json <<-EOF

VLess runs on ${configV2rayPortShowInfo} port (VLess-TCP-TLS) + (VMess-TCP-TLS) + (VMess-WS-TLS) CDN support

=========== ${promptInfoXrayInstall}Client VLess-TCP-TLS Configuration Parameters =============
{
    Protocol: VLess,
    Address: ${configSSLDomain},
    Port: ${configV2rayPort},
    uuid: ${v2rayPassword1},
    Extra id: 0, // AlterID is not required if it is Vless protocol
    Flow control flow: ${configV2rayVlessXtlsFlowShowInfo},
    Encryption method: none, // none if Vless protocol
    Transmission protocol: tcp ,
    websocket path: none,
    The underlying transport protocol: ${configV2rayIsTlsShowInfo},
    Aliases: give yourself an arbitrary name
}

Import link Vless format:
${v2rayVlessLinkQR1}


=========== ${promptInfoXrayInstall}Client VMess-WS-TLS configuration parameters support CDN =============
{
    Protocol: VMess,
    Address: ${configSSLDomain},
    Port: ${configV2rayPort},
    uuid: ${v2rayPassword1},
    Extra id: 0, // AlterID is not required if it is Vless protocol
    Encryption method: auto, // none if Vless protocol
    Transport protocol: websocket,
    websocket path:/${configV2rayWebSocketPath},
    The underlying transport protocol: tls,
    Aliases: give yourself an arbitrary name
}

Import link in Vmess Base64 format:
${v2rayVmessLinkQR1}



=========== ${promptInfoXrayInstall}Client VMess-TCP-TLS configuration parameters support CDN =============
{
    Protocol: VMess,
    Address: ${configSSLDomain},
    Port: ${configV2rayPort},
    uuid: ${v2rayPassword1},
    Extra id: 0, // AlterID is not required if it is Vless protocol
    Encryption method: auto, // none if Vless protocol
    Transmission protocol: tcp,
    Masquerade type: http,
    Path:/tcp${configV2rayWebSocketPath},
    The underlying transport protocol: tls,
    Aliases: give yourself an arbitrary name
}

Import link in Vmess Base64 format:
${v2rayVmessLinkQR2}


EOF

    elif [[ "$configV2rayWorkingMode" == "vlessgRPC" ]]; then

    cat > ${configV2rayPath}/clientConfig.json <<-EOF
 VLess runs on ${configV2rayPortShowInfo} port (VLess-gRPC-TLS) CDN support

=========== ${promptInfoXrayInstall}Client VLess-gRPC-TLS configuration parameters support CDN =============
{
    Protocol: VLess,
    Address: ${configSSLDomain},
    Port: ${configV2rayPort},
    uuid: ${v2rayPassword1},
    Extra id: 0, // AlterID is not required if it is Vless protocol
    Flow control flow: ${configV2rayVlessXtlsFlowShowInfo},
    Encryption method: none,  
    Transport protocol: gRPC,
    gRPC serviceName: ${configV2rayGRPCServiceName},
    The underlying transport protocol: ${configV2rayIsTlsShowInfo},
    Aliases: give yourself an arbitrary name
}

Import link Vless format:
${v2rayVlessLinkQR1}

EOF

    elif [[ "$configV2rayWorkingMode" == "vlessTCPWS" ]]; then

    cat > ${configV2rayPath}/clientConfig.json <<-EOF
VLess runs on ${configV2rayPortShowInfo} port (VLess-TCP-TLS) + (VLess-WS-TLS) supports CDN

=========== ${promptInfoXrayInstall}Client VLess-TCP-TLS Configuration Parameters =============
{
    Protocol: VLess,
    Address: ${configSSLDomain},
    Port: ${configV2rayPort},
    uuid: ${v2rayPassword1},
    Extra id: 0, // AlterID is not required if it is Vless protocol
    Flow control flow: ${configV2rayVlessXtlsFlowShowInfo},
    Encryption method: none,
    Transmission protocol: tcp ,
    websocket path: none,
    The underlying transport protocol: ${configV2rayIsTlsShowInfo},
    Aliases: give yourself an arbitrary name
}

Import link Vless format:
${v2rayVlessLinkQR1}


=========== ${promptInfoXrayInstall}Client VLess-WS-TLS configuration parameters support CDN =============
{
    Protocol: VLess,
    Address: ${configSSLDomain},
    Port: ${configV2rayPort},
    uuid: ${v2rayPassword1},
    Extra id: 0, // AlterID is not required if it is Vless protocol
    Flow control flow: ${configV2rayVlessXtlsFlowShowInfo},
    Encryption method: none,  
    Transport protocol: websocket,
    websocket path:/${configV2rayWebSocketPath},
    The underlying transport protocol: tls,     
    Aliases: give yourself an arbitrary name
}

Import link Vless format:
vless://${v2rayPassword1UrlEncoded}@${configSSLDomain}:${configV2rayPortShowInfo}?encryption=none&security=tls&type=ws&host=${configSSLDomain}&path=%2f${configV2rayWebSocketPath}#${configSSLDomain}+ws_protocol

EOF

    elif [[ "$configV2rayWorkingMode" == "vlessTCPWSgRPC" || "$configV2rayWorkingMode" == "sni" ]]; then

    cat > ${configV2rayPath}/clientConfig.json <<-EOF
VLess runs on ${configV2rayPortShowInfo} port (VLess-TCP-TLS) + (VLess-WS-TLS) + (VLess-gRPC-TLS) supports CDN

=========== ${promptInfoXrayInstall}Client VLess-TCP-TLS Configuration Parameters =============
{
    Protocol: VLess,
    Address: ${configSSLDomain},
    Port: ${configV2rayPortShowInfo},
    uuid: ${v2rayPassword1},
    Extra id: 0, // AlterID is not required if it is Vless protocol
    flow control flow: empty
    Encryption method: none,
    Transmission protocol: tcp ,
    websocket path: none,
    The underlying transport protocol: ${configV2rayIsTlsShowInfo},
    Aliases: give yourself an arbitrary name
}

Import link Vless format:
${v2rayVlessLinkQR1}


=========== ${promptInfoXrayInstall}Client VLess-WS-TLS configuration parameters support CDN =============
{
    Protocol: VLess,
    Address: ${configSSLDomain},
    Port: ${configV2rayPortShowInfo},
    uuid: ${v2rayPassword1},
    Extra id: 0, // AlterID is not required if it is Vless protocol
    Flow control flow: ${configV2rayVlessXtlsFlowShowInfo},
    Encryption method: none,  
    Transport protocol: websocket,
    websocket path:/${configV2rayWebSocketPath},
    The underlying transport protocol: tls,     
    Aliases: give yourself an arbitrary name
}

Import link Vless format:
vless://${v2rayPassword1UrlEncoded}@${configSSLDomain}:${configV2rayPortShowInfo}?encryption=none&security=tls&type=ws&host=${configSSLDomain}&path=%2f${configV2rayWebSocketPath}#${configSSLDomain}+ws_protocol


=========== ${promptInfoXrayInstall}Client VLess-gRPC-TLS configuration parameters support CDN =============
{
    Protocol: VLess,
    Address: ${configSSLDomain},
    Port: ${configV2rayPortShowInfo},
    uuid: ${v2rayPassword1},
    Extra id: 0, // AlterID is not required if it is Vless protocol
    flow control flow: empty,
    Encryption method: none,  
    Transport protocol: gRPC,
    gRPC serviceName: ${configV2rayGRPCServiceName},
    The underlying transport protocol: tls,     
    Aliases: give yourself an arbitrary name
}

Import link Vless format:
vless://${v2rayPassword1UrlEncoded}@${configSSLDomain}:${configV2rayPortShowInfo}?encryption=none&security=tls&type=grpc&serviceName=${configV2rayGRPCServiceName}&host=${configSSLDomain}#${configSSLDomain}+gRPC_protocol

EOF

    elif [[ "$configV2rayWorkingMode" == "vlessTCPWSTrojan" ]]; then
    cat > ${configV2rayPath}/clientConfig.json <<-EOF
VLess runs on ${configV2rayPortShowInfo} port (VLess-TCP-TLS) + (VLess-WS-TLS) + (Trojan) supporting CDN

=========== ${promptInfoXrayInstall}Client VLess-TCP-TLS Configuration Parameters =============
{
    Protocol: VLess,
    Address: ${configSSLDomain},
    Port: ${configV2rayPort},
    uuid: ${v2rayPassword1},
    Extra id: 0, // AlterID is not required if it is Vless protocol
    Flow control flow: xtls-rprx-direct
    Encryption method: none,  
    Transmission protocol: tcp ,
    websocket path: none,
    The underlying transport protocol: ${configV2rayIsTlsShowInfo},
    Aliases: give yourself an arbitrary name
}

Import link Vless format:
${v2rayVlessLinkQR1}


=========== ${promptInfoXrayInstall}Client VLess-WS-TLS configuration parameters support CDN =============
{
    Protocol: VLess,
    Address: ${configSSLDomain},
    Port: ${configV2rayPort},
    uuid: ${v2rayPassword1},
    Extra id: 0, // AlterID is not required if it is Vless protocol
    Flow control flow: ${configV2rayVlessXtlsFlowShowInfo},
    Encryption method: none,  
    Transport protocol: websocket,
    websocket path:/${configV2rayWebSocketPath},
    The underlying transport protocol: tls,     
    Aliases: give yourself an arbitrary name
}

Import link:
vless://${v2rayPassword1UrlEncoded}@${configSSLDomain}:${configV2rayPort}?encryption=none&security=tls&type=ws&host=${configSSLDomain}&path=%2f${configV2rayWebSocketPath}#${configSSLDomain}+ws_protocol


=========== Trojan${promptInfoTrojanName}Server Address: ${configSSLDomain} Port: $configV2rayPort

Password1: ${trojanPassword1}
Password2: ${trojanPassword2}
Password3: ${trojanPassword3}
Password 4: ${trojanPassword4}
Password 5: ${trojanPassword5}
Password 6: ${trojanPassword6}
Password 7: ${trojanPassword7}
Password8: ${trojanPassword8}
Password9: ${trojanPassword9}
Password10: ${trojanPassword10}
There are 20 passwords with the prefix you specify: from ${configTrojanPasswordPrefixInput}202001 to ${configTrojanPasswordPrefixInput}202020 can be used
For example: password:${configTrojanPasswordPrefixInput}202002 or password:${configTrojanPasswordPrefixInput}202019 can be used

Little Rocket Link:
trojan://${trojanPassword1}@${configSSLDomain}:${configV2rayPort}?peer=${configSSLDomain}&sni=${configSSLDomain}#${configSSLDomain}_trojan

QR code Trojan${promptInfoTrojanName}
https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=trojan%3a%2f%2f${trojanPassword1}%40${configSSLDomain}%3a${configV2rayPort}%3fpeer%3d${configSSLDomain}%26sni%3d${configSSLDomain}%23${configSSLDomain}_trojan

EOF

    elif [[ "$configV2rayWorkingMode" == "trojan" ]]; then
    cat > ${configV2rayPath}/clientConfig.json <<-EOF
=========== ${promptInfoXrayInstall}Client VLess-TCP-TLS Configuration Parameters =============
{
    Protocol: VLess,
    Address: ${configSSLDomain},
    Port: ${configV2rayPort},
    uuid: ${v2rayPassword1},
    Extra id: 0, // AlterID is not required if it is Vless protocol
    Flow control flow: xtls-rprx-direct
    Encryption method: none,  
    Transmission protocol: tcp ,
    websocket path: none,
    The underlying transport protocol: ${configV2rayIsTlsShowInfo},
    Aliases: give yourself an arbitrary name
}

Import link Vless format:
${v2rayVlessLinkQR1}


=========== ${promptInfoXrayInstall}Client VLess-WS-TLS configuration parameters support CDN =============
{
    Protocol: VLess,
    Address: ${configSSLDomain},
    Port: ${configV2rayPort},
    uuid: ${v2rayPassword1},
    Extra id: 0, // AlterID is not required if it is Vless protocol
    Flow control flow: ${configV2rayVlessXtlsFlowShowInfo},
    Encryption method: none,  
    Transport protocol: websocket,
    websocket path:/${configV2rayWebSocketPath},
    The underlying transport protocol: tls,     
    Aliases: give yourself an arbitrary name
}

Import link:
vless://${v2rayPassword1UrlEncoded}@${configSSLDomain}:${configV2rayPort}?encryption=none&security=tls&type=ws&host=${configSSLDomain}&path=%2f${configV2rayWebSocketPath}#${configSSLDomain}+ws_protocol


=========== Trojan${promptInfoTrojanName}Server Address: ${configSSLDomain} Port: $configV2rayTrojanPort

Password1: ${trojanPassword1}
Password2: ${trojanPassword2}
Password3: ${trojanPassword3}
Password 4: ${trojanPassword4}
Password 5: ${trojanPassword5}
Password 6: ${trojanPassword6}
Password 7: ${trojanPassword7}
Password8: ${trojanPassword8}
Password9: ${trojanPassword9}
Password10: ${trojanPassword10}
There are 20 passwords with the prefix you specify: from ${configTrojanPasswordPrefixInput}202001 to ${configTrojanPasswordPrefixInput}202020 can be used
For example: password:${configTrojanPasswordPrefixInput}202002 or password:${configTrojanPasswordPrefixInput}202019 can be used

Little Rocket Link:
trojan://${trojanPassword1}@${configSSLDomain}:${configV2rayTrojanPort}?peer=${configSSLDomain}&sni=${configSSLDomain}#${configSSLDomain}_trojan

QR code Trojan${promptInfoTrojanName}
https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=trojan%3a%2f%2f${trojanPassword1}%40${configSSLDomain}%3a${configV2rayTrojanPort}%3fpeer%3d${configSSLDomain}%26sni%3d${configSSLDomain}%23${configSSLDomain}_trojan

EOF
    fi



    # Set up cron scheduled tasks
    # https://stackoverflow.com/questions/610839/how-can-i-programmatically-create-a-new-cron-job

    (crontab -l ; echo "20 4 * * 0,1,2,3,4,5,6 systemctl restart ${promptInfoXrayName}${promptInfoXrayNameServiceName}.service") | sort - | uniq - | crontab -


    green "======================================================================"
    green " ${promptInfoXrayInstall} Version: ${promptInfoXrayVersion} installed successfully!"

    if [[ -n ${configInstallNginxMode} ]]; then
        green "Pretend the site is https://${configSSLDomain}!"
	    green "The static html content of the disguised site is placed in the directory ${configWebsitePath}, and the content of the website can be replaced by yourself!"
    fi
	
	red " ${promptInfoXrayInstall} server-side configuration path ${configV2rayPath}/config.json !"
	green " ${promptInfoXrayInstall} access log ${configV2rayAccessLogFilePath} !"
	green " ${promptInfoXrayInstall} error log ${configV2rayErrorLogFilePath} ! "
	green " ${promptInfoXrayInstall} View log command: journalctl -n 50 -u ${promptInfoXrayName}${promptInfoXrayNameServiceName}.service "
	green " ${promptInfoXrayInstall} stop command: systemctl stop ${promptInfoXrayName}${promptInfoXrayNameServiceName}.service start command: systemctl start ${promptInfoXrayName}${promptInfoXrayNameServiceName}.service "
	green " ${promptInfoXrayInstall} restart command: systemctl restart ${promptInfoXrayName}${promptInfoXrayNameServiceName}.service"
	green " ${promptInfoXrayInstall} View running status command: systemctl status ${promptInfoXrayName}${promptInfoXrayNameServiceName}.service "
	green " ${promptInfoXrayInstall} server will automatically restart every day to prevent memory leaks. Run crontab -l command to view scheduled restart commands!"
	green "======================================================================"
	echo ""
	yellow "${promptInfoXrayInstall} configuration information is as follows, please copy and save it yourself, choose one of the passwords (password is user ID or UUID) !!"
	yellow "Server Address: ${configSSLDomain} Port: ${configV2rayPortShowInfo}"
	yellow "User ID or Password 1: ${v2rayPassword1}"
	yellow "User ID or Password 2: ${v2rayPassword2}"
	yellow "User ID or Password 3: ${v2rayPassword3}"
	yellow "User ID or Password 4: ${v2rayPassword4}"
	yellow "User ID or Password 5: ${v2rayPassword5}"
	yellow "User ID or Password 6: ${v2rayPassword6}"
	yellow "User ID or Password 7: ${v2rayPassword7}"
	yellow "User ID or Password 8: ${v2rayPassword8}"
	yellow "User ID or Password 9: ${v2rayPassword9}"
	yellow "User ID or Password 10: ${v2rayPassword10}"
    echo ""
	cat "${configV2rayPath}/clientConfig.json"
	echo ""
    green "======================================================================"
    green "Please download the corresponding ${promptInfoXrayName} client:"
    yellow "1 Windows client V2rayN download: http://${configSSLDomain}/download/${configTrojanWindowsCliPrefixPath}/v2ray-windows.zip"
    yellow "2 MacOS client download: http://${configSSLDomain}/download/${configTrojanWindowsCliPrefixPath}/v2ray-mac.zip"
    yellow "3 Android client download https://github.com/2dust/v2rayNG/releases"
    #yellow "3 Android client download http://${configSSLDomain}/download/${configTrojanWindowsCliPrefixPath}/v2ray-android.zip"
    yellow "4 iOS client please install Little Rocket https://shadowsockshelp.github.io/ios/ "
    yellow " iOS please install Xiaorocket another address https://lueyingpro.github.io/shadowrocket/index.html "
    yellow " iOS installation of small rocket encountered problems tutorial https://github.com/shadowrocketHelp/help/ "
    yellow "Summary of all-platform client programs https://tlanyan.pp.ua/v2ray-clients-download/ "
    yellow "For other client programs, please see https://www.v2fly.org/awesome/tools.html "
    green "======================================================================"

    cat >> ${configReadme} <<-EOF


${promptInfoXrayInstall} Version: ${promptInfoXrayVersion} successfully installed!
${promptInfoXrayInstall} server-side configuration path ${configV2rayPath}/config.json

${promptInfoXrayInstall} Access Log ${configV2rayAccessLogFilePath}
${promptInfoXrayInstall} error log ${configV2rayErrorLogFilePath}

${promptInfoXrayInstall} View log command: journalctl -n 50 -u ${promptInfoXrayName}${promptInfoXrayNameServiceName}.service

${promptInfoXrayInstall} Start command: systemctl start ${promptInfoXrayName}${promptInfoXrayNameServiceName}.service  
${promptInfoXrayInstall} stop instruction: systemctl stop ${promptInfoXrayName}${promptInfoXrayNameServiceName}.service  
${promptInfoXrayInstall} Restart command: systemctl restart ${promptInfoXrayName}${promptInfoXrayNameServiceName}.service
${promptInfoXrayInstall} View running status command: systemctl status ${promptInfoXrayName}${promptInfoXrayNameServiceName}.service

The configuration information of ${promptInfoXrayInstall} is as follows, please copy and save it yourself, and choose one of the passwords (the password is the user ID or UUID) !

Server address: ${configSSLDomain}  
Port: ${configV2rayPortShowInfo}
User ID or Password 1: ${v2rayPassword1}
User ID or Password 2: ${v2rayPassword2}
User ID or Password 3: ${v2rayPassword3}
User ID or Password 4: ${v2rayPassword4}
User ID or Password 5: ${v2rayPassword5}
User ID or Password 6: ${v2rayPassword6}
User ID or Password 7: ${v2rayPassword7}
User ID or Password 8: ${v2rayPassword8}
User ID or Password 9: ${v2rayPassword9}
User ID or Password 10: ${v2rayPassword10}

EOF

    cat "${configV2rayPath}/clientConfig.json" >> ${configReadme}
}

function removeV2ray(){

    echo
    read -p "Are you sure to uninstall V2ray or Xray? Press Enter to uninstall by default, please input [Y/n]:" isRemoveV2rayServerInput
    isRemoveV2rayServerInput=${isRemoveV2rayServerInput:-Y}

    if [[ "${isRemoveV2rayServerInput}" == [Yy] ]]; then


        if [[ -f "${configV2rayPath}/xray" || -f "${configV2rayPath}/v2ray" ]]; then

            if [ -f "${configV2rayPath}/xray" ]; then
                promptInfoXrayName="xray"
                isXray="yes"
            fi

            tempIsXrayService=$(ls ${osSystemMdPath} | grep xray- )
            if [[ -z "${tempIsXrayService}" ]]; then
                promptInfoXrayNameServiceName=""

            else
                if [ -f "${osSystemMdPath}${promptInfoXrayName}-jin.service" ]; then
                    promptInfoXrayNameServiceName="-jin"
                else
                    tempFilelist=$(ls /usr/lib/systemd/system | grep xray | awk -F '-' '{ print $2 }' )
                    promptInfoXrayNameServiceName="-${tempFilelist%.*}"
                fi
            fi


            echo
            green " ================================================== "
            red "Ready to uninstall installed ${promptInfoXrayName}${promptInfoXrayNameServiceName}"
            green " ================================================== "
            echo

            ${sudoCmd} systemctl stop ${promptInfoXrayName}${promptInfoXrayNameServiceName}.service
            ${sudoCmd} systemctl disable ${promptInfoXrayName}${promptInfoXrayNameServiceName}.service


            rm -rf ${configV2rayPath}
            rm -f ${osSystemMdPath}${promptInfoXrayName}${promptInfoXrayNameServiceName}.service
            rm -f ${configV2rayAccessLogFilePath}
            rm -f ${configV2rayErrorLogFilePath}

            crontab -l | grep -v "${promptInfoXrayName}${promptInfoXrayNameServiceName}" | crontab -

            echo
            green " ================================================== "
            green " ${promptInfoXrayName}${promptInfoXrayNameServiceName} uninstall complete!"
            green " ================================================== "
            
        else
            red "${promptInfoXrayName}${promptInfoXrayNameServiceName} is not installed in the system, exit uninstall"
        fi
        echo

    fi

}


function upgradeV2ray(){

    if [[ -f "${configV2rayPath}/xray" || -f "${configV2rayPath}/v2ray" ]]; then
        if [ -f "${configV2rayPath}/xray" ]; then
            promptInfoXrayName="xray"
            isXray="yes"
        fi

        tempIsXrayService=$(ls ${osSystemMdPath} | grep xray- )
        if [[ -z "${tempIsXrayService}" ]]; then
            promptInfoXrayNameServiceName=""

        else
            if [ -f "${osSystemMdPath}${promptInfoXrayName}-jin.service" ]; then
                promptInfoXrayNameServiceName="-jin"
            else
                tempFilelist=$(ls ${osSystemMdPath} | grep xray | awk -F '-' '{ print $2 }' )
                promptInfoXrayNameServiceName="-${tempFilelist%.*}"
            fi
        fi
        

        if [ "$isXray" = "no" ] ; then
            getTrojanAndV2rayVersion "v2ray"
            green " =================================================="
            green "Start upgrading V2ray Version: ${versionV2ray} !"
            green " =================================================="
        else
            getTrojanAndV2rayVersion "xray"
            green " =================================================="
            green "Start upgrading Xray Version: ${versionXray} !"
            green " =================================================="
        fi


        ${sudoCmd} systemctl stop ${promptInfoXrayName}${promptInfoXrayNameServiceName}.service

        mkdir -p ${configDownloadTempPath}/upgrade/${promptInfoXrayName}

        downloadV2rayXrayBin "upgrade"

        if [ "$isXray" = "no" ] ; then
            mv -f ${configDownloadTempPath}/upgrade/${promptInfoXrayName}/v2ctl ${configV2rayPath}
        fi

        mv -f ${configDownloadTempPath}/upgrade/${promptInfoXrayName}/${promptInfoXrayName} ${configV2rayPath}
        mv -f ${configDownloadTempPath}/upgrade/${promptInfoXrayName}/geoip.dat ${configV2rayPath}
        mv -f ${configDownloadTempPath}/upgrade/${promptInfoXrayName}/geosite.dat ${configV2rayPath}

        ${sudoCmd} chmod +x ${configV2rayPath}/${promptInfoXrayName}
        ${sudoCmd} systemctl start ${promptInfoXrayName}${promptInfoXrayNameServiceName}.service


        if [ "$isXray" = "no" ] ; then
            green " ================================================== "
            green "Upgrade successful V2ray Version: ${versionV2ray} !"
            green " ================================================== "
        else
            getTrojanAndV2rayVersion "xray"
            green " =================================================="
            green "Upgrade successful Xray Version: ${versionXray} !"
            green " =================================================="
        fi
                
    else
        red "${promptInfoXrayName}${promptInfoXrayNameServiceName} is not installed in the system, exit uninstall"
    fi
    echo
}











































function downloadTrojanWebBin(){
    # https://github.com/Jrohy/trojan/releases/download/v2.12.2/trojan-linux-amd64
    # https://github.com/Jrohy/trojan/releases/download/v2.12.2/trojan-linux-arm64
    
    if [[ ${osArchitecture} == "arm" || ${osArchitecture} == "arm64" ]] ; then
        downloadFilenameTrojanWeb="trojan-linux-arm64"
    fi

    if [ -z $1 ]; then
        wget -O ${configTrojanWebPath}/trojan-web --no-check-certificate "https://github.com/Jrohy/trojan/releases/download/v${versionTrojanWeb}/${downloadFilenameTrojanWeb}"
    else
        wget -O ${configDownloadTempPath}/upgrade/trojan-web/trojan-web "https://github.com/Jrohy/trojan/releases/download/v${versionTrojanWeb}/${downloadFilenameTrojanWeb}"
    fi
}

function installTrojanWeb(){
    # wget -O trojan-web_install.sh -N --no-check-certificate "https://raw.githubusercontent.com/Jrohy/trojan/master/install.sh" && chmod +x trojan-web_install.sh && ./trojan-web_install.sh

    if [ -f "${configTrojanWebPath}/trojan-web" ] ; then
        green " =================================================="
        green "The Trojan-web visual management panel has been installed, exit the installation!"
        green " =================================================="
        exit
    fi

    stopServiceNginx
    testLinuxPortUsage
    installPackage

    green " ================================================== "
    yellow "Please enter the domain name bound to this VPS, such as www.xxx.com: (Please close the CDN and install after this step)"
    green " ================================================== "

    read configSSLDomain
    if compareRealIpWithLocalIp "${configSSLDomain}" ; then

        getTrojanAndV2rayVersion "trojan-web"
        green " =================================================="
        green "Start installing Trojan-web visual admin panel: ${versionTrojanWeb} !"
        green " =================================================="

        mkdir -p ${configTrojanWebPath}
        downloadTrojanWebBin
        chmod +x ${configTrojanWebPath}/trojan-web


        # Add startup script
        cat > ${osSystemMdPath}trojan-web.service <<-EOF
[Unit]
Description=trojan-web
Documentation=https://github.com/Jrohy/trojan
After=network.target network-online.target nss-lookup.target mysql.service mariadb.service mysqld.service docker.service

[Service]
Type=simple
StandardError=journal
ExecStart=${configTrojanWebPath}/trojan-web web -p ${configTrojanWebPort}
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=3s

[Install]
WantedBy=multi-user.target
EOF

        ${sudoCmd} systemctl daemon-reload
        ${sudoCmd} systemctl enable trojan-web.service
        ${sudoCmd} systemctl start trojan-web.service

        green " =================================================="
        green "Trojan-web visual management panel: ${versionTrojanWeb} installed successfully!"
        green "Trojan visual management panel address https://${configSSLDomain}/${configTrojanWebNginxPath}"
        green "Start running the command ${configTrojanWebPath}/trojan-web for initial setup."
        echo
        red "Next installation steps: "
        green "According to the prompts, select 1. Let's Encrypt certificate, apply for SSL certificate"
        green "After the certificate application is successful. Continue to follow the prompts and select 1. Install the docker version of mysql(mariadb)."
        green "After mysql(mariadb) starts successfully, continue to enter the account password of the first trojan user according to the prompt, and after pressing Enter, 'Welcome to the trojan management program' appears"
        green "After 'Welcome to the trojan management program' appears, you need to press Enter without entering a number, which will continue to install nginx until it is completed"
        echo
        green " The nginx installation will display the URL of the visual management panel, please save it. If the URL of the management panel is not displayed, the installation fails. "
        green " =================================================="

        read -p "Press enter to continue the installation. Press enter to continue"

        ${configTrojanWebPath}/trojan-web

        installWebServerNginx

        #Command completion environment variables
        echo "export PATH=$PATH:${configTrojanWebPath}" >> ${HOME}/.${osSystemShell}rc

        # (crontab -l ; echo '25 0 * * * "${configSSLAcmeScriptPath}"/acme.sh --cron --home "${configSSLAcmeScriptPath}" > /dev/null') | sort - | uniq - | crontab -
        (crontab -l ; echo "30 4 * * 0,1,2,3,4,5,6 systemctl restart trojan-web.service") | sort - | uniq - | crontab -

    else
        exit
    fi
}

function upgradeTrojanWeb(){
    getTrojanAndV2rayVersion "trojan-web"
    green " =================================================="
    green "Start upgrading Trojan-web visual admin panel: ${versionTrojanWeb} !"
    green " =================================================="

    ${sudoCmd} systemctl stop trojan-web.service

    mkdir -p ${configDownloadTempPath}/upgrade/trojan-web
    downloadTrojanWebBin "upgrade"
    
    mv -f ${configDownloadTempPath}/upgrade/trojan-web/trojan-web ${configTrojanWebPath}
    chmod +x ${configTrojanWebPath}/trojan-web

    ${sudoCmd} systemctl start trojan-web.service
    ${sudoCmd} systemctl restart trojan.service


    green " ================================================== "
    green "Upgrade successfully Trojan-web visual management panel: ${versionTrojanWeb} !"
    green " ================================================== "
}

function removeTrojanWeb(){
    # wget -O trojan-web_install.sh -N --no-check-certificate "https://raw.githubusercontent.com/Jrohy/trojan/master/install.sh" && chmod +x trojan-web_install.sh && ./trojan-web_install.sh --remove

    green " ================================================== "
    red "Ready to uninstall Trojan-web installed"
    green " ================================================== "

    ${sudoCmd} systemctl stop trojan.service
    ${sudoCmd} systemctl stop trojan-web.service
    ${sudoCmd} systemctl disable trojan-web.service
    

    # remove trojan
    rm -rf /usr/bin/trojan
    rm -rf /usr/local/etc/trojan
    rm -f ${osSystemMdPath}trojan.service
    rm -f /etc/systemd/system/trojan.service
    rm -f /usr/local/etc/trojan/config.json


    # remove trojan web manager
    # rm -f /usr/local/bin/trojan
    rm -rf ${configTrojanWebPath}
    rm -f ${osSystemMdPath}trojan-web.service
    rm -rf /var/lib/trojan-manager

    ${sudoCmd} systemctl daemon-reload


    # Remove trojan's private database
    docker rm -f trojan-mysql
    docker rm -f trojan-mariadb
    rm -rf /home/mysql
    rm -rf /home/mariadb


    # remove environment variables
    sed -i '/trojan/d' ${HOME}/.${osSystemShell}rc
    # source ${HOME}/.${osSystemShell}rc

    crontab -l | grep -v "trojan-web"  | crontab -

    green " ================================================== "
    green "Trojan-web uninstallation completed!"
    green " ================================================== "
}

function runTrojanWebGetSSL(){
    ${sudoCmd} systemctl stop trojan-web.service
    ${sudoCmd} systemctl stop nginx.service
    ${sudoCmd} systemctl stop trojan.service
    ${configTrojanWebPath}/trojan-web tls
    ${sudoCmd} systemctl start trojan-web.service
    ${sudoCmd} systemctl start nginx.service
    ${sudoCmd} systemctl restart trojan.service
}

function runTrojanWebCommand(){
    ${configTrojanWebPath}/trojan-web
}




























function installXUI(){

    stopServiceNginx
    testLinuxPortUsage
    installPackage

    green " ================================================== "
    yellow "Please enter the domain name bound to this VPS, such as www.xxx.com: (Please close the CDN and install after this step)"
    green " ================================================== "

    read -r configSSLDomain
    if compareRealIpWithLocalIp "${configSSLDomain}" ; then

        green " =================================================="
        green "Start installing the X-UI visual management panel!"
        green " =================================================="

        # wget -O x_ui_install.sh -N --no-check-certificate "https://raw.githubusercontent.com/sprov065/x-ui/master/install.sh" && chmod +x x_ui_install.sh && ./x_ui_install.sh
        wget -O x_ui_install.sh -N --no-check-certificate "https://raw.githubusercontent.com/vaxilu/x-ui/master/install.sh" && chmod +x x_ui_install.sh && ./x_ui_install.sh

        green "X-UI visual management panel address http://${configSSLDomain}:54321"
        green "Please make sure port 54321 has been released, for example, check whether port 54321 of linux firewall or VPS firewall is open"
        green "X-UI visual management panel default administrator user admin password admin, to ensure security, please change the default password as soon as possible after logging in"
        green " =================================================="

    else
        exit
    fi
}
function removeXUI(){
    green " =================================================="
    /usr/bin/x-ui
}


function installV2rayUI(){

    stopServiceNginx
    testLinuxPortUsage
    installPackage

    green " ================================================== "
    yellow "Please enter the domain name bound to this VPS, such as www.xxx.com: (Please close the CDN and install after this step)"
    green " ================================================== "

    read -r configSSLDomain
    if compareRealIpWithLocalIp "${configSSLDomain}" ; then

        green " =================================================="
        green "Start installing V2ray-UI visual management panel!"
        green " =================================================="

        bash <(curl -Ls https://raw.githubusercontent.com/tszho-t/v2ui/master/v2-ui.sh)

        # wget -O v2_ui_install.sh -N --no-check-certificate "https://raw.githubusercontent.com/sprov065/v2-ui/master/install.sh" && chmod +x v2_ui_install.sh && ./v2_ui_install.sh
        # wget -O v2_ui_install.sh -N --no-check-certificate "https://raw.githubusercontent.com/tszho-t/v2-ui/master/install.sh" && chmod +x v2_ui_install.sh && ./v2_ui_install.sh

        green " V2ray-UI visual management panel address http://${configSSLDomain}:65432"
        green "Please make sure port 65432 has been released, for example, check whether port 65432 of linux firewall or VPS firewall is open"
        green " V2ray-UI visual management panel default administrator user admin password admin, to ensure security, please change the default password as soon as possible after logging in"
        green " =================================================="

    else
        exit
    fi
}
function removeV2rayUI(){
    green " =================================================="
    /usr/bin/v2-ui
}
function upgradeV2rayUI(){
    green " =================================================="
    /usr/bin/v2-ui
}















































configMosdnsPath="/usr/local/bin/mosdns"
isInstallMosdns="true"
isinstallMosdnsName="mosdns"
downloadFilenameMosdns="mosdns-linux-amd64.zip"
downloadFilenameMosdnsCn="mosdns-cn-linux-amd64.zip"


function downloadMosdns(){

    rm -rf "${configMosdnsPath}"
    mkdir -p "${configMosdnsPath}"
    cd ${configMosdnsPath} || exit
    
    if [[ "${isInstallMosdns}" == "true" ]]; then
        versionMosdns=$(getGithubLatestReleaseVersion "IrineSistiana/mosdns")

        downloadFilenameMosdns="mosdns-linux-amd64.zip"

        # https://github.com/IrineSistiana/mosdns/releases/download/v3.8.0/mosdns-linux-amd64.zip
        # https://github.com/IrineSistiana/mosdns/releases/download/v3.8.0/mosdns-linux-arm64.zip
        # https://github.com/IrineSistiana/mosdns/releases/download/v3.8.0/mosdns-linux-arm-7.zip
        if [[ ${osArchitecture} == "arm" ]] ; then
            downloadFilenameMosdns="mosdns-linux-arm-7.zip"
        fi
        if [[ ${osArchitecture} == "arm64" ]] ; then
            downloadFilenameMosdns="mosdns-linux-arm64.zip"
        fi
        
        downloadAndUnzip "https://github.com/IrineSistiana/mosdns/releases/download/v${versionMosdns}/${downloadFilenameMosdns}" "${configMosdnsPath}" "${downloadFilenameMosdns}"
        ${sudoCmd} chmod +x "${configMosdnsPath}/mosdns"
    
    else
        versionMosdnsCn=$(getGithubLatestReleaseVersion "IrineSistiana/mosdns-cn")

        downloadFilenameMosdnsCn="mosdns-cn-linux-amd64.zip"

        # https://github.com/IrineSistiana/mosdns-cn/releases/download/v1.2.3/mosdns-cn-linux-amd64.zip
        # https://github.com/IrineSistiana/mosdns-cn/releases/download/v1.2.3/mosdns-cn-linux-arm64.zip
        # https://github.com/IrineSistiana/mosdns-cn/releases/download/v1.2.3/mosdns-cn-linux-arm-7.zip
        if [[ ${osArchitecture} == "arm" ]] ; then
            downloadFilenameMosdnsCn="mosdns-cn-linux-arm-7.zip"
        fi
        if [[ ${osArchitecture} == "arm64" ]] ; then
            downloadFilenameMosdnsCn="mosdns-cn-linux-arm64.zip"
        fi

        downloadAndUnzip "https://github.com/IrineSistiana/mosdns-cn/releases/download/v${versionMosdnsCn}/${downloadFilenameMosdnsCn}" "${configMosdnsPath}" "${downloadFilenameMosdnsCn}"
        ${sudoCmd} chmod +x "${configMosdnsPath}/mosdns-cn"
    fi

    if [ ! -f "${configMosdnsPath}/${isinstallMosdnsName}" ]; then
        echo
        red "Failed to download, please check if the network can access gitHub.com normally"
        red "Please check the network and run this script again!"
        echo
        exit 1
    fi 

    echo
    green "Downloading files: cn.dat, geosite.dat, geoip.dat."
    green "Start downloading files: cn.dat, geosite.dat, geoip.dat and other related files"
    echo

    # versionV2rayRulesDat=$(getGithubLatestReleaseVersion "Loyalsoldier/v2ray-rules-dat")
    # geositeUrl="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/202205162212/geosite.dat"
    # geoipeUrl="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/202205162212/geoip.dat"
    # cnipUrl="https://github.com/Loyalsoldier/geoip/releases/download/202205120123/cn.dat"

    geositeFilename="geosite.dat"
    geoipFilename="geoip.dat"
    cnipFilename="cn.dat"

    geositeUrl="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"
    geoipeUrl="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
    cnipUrl="https://raw.githubusercontent.com/Loyalsoldier/geoip/release/cn.dat"


    wget -O ${configMosdnsPath}/${geositeFilename} ${geositeUrl}
    wget -O ${configMosdnsPath}/${geoipFilename} ${geoipeUrl}
    wget -O ${configMosdnsPath}/${cnipFilename} ${cnipUrl}

}


function installMosdns(){

    if [ "${osInfo}" = "OpenWrt" ]; then
        echo " ================================================== "
        echo " For Openwrt X86, please use the script below:  "
        echo "For OpenWrt X86 systems, use the following script to install: "
        echo " wget --no-check-certificate https://raw.githubusercontent.com/jinwyp/one_click_script/master/dsm/openwrt.sh && chmod +x ./openwrt.sh && ./openwrt.sh "
        echo
        exit
    fi
    
    # https://askubuntu.com/questions/27213/what-is-the-linux-equivalent-to-windows-program-files


    if [ -f "${configMosdnsPath}/mosdns" ]; then
        echo
        green " =================================================="
        green "Detected that moddns is installed, exit the installation!"
        echo
        exit 1
    fi


    if [ -f "${configMosdnsPath}/mosdns-cn" ]; then
        echo
        green " =================================================="
        green "Detected that moddns-cn is installed, exit the installation!"
        echo
        exit 1        
    fi

    echo
    green " =================================================="
    green "Please choose to install Mosdns or Mosdns-cn DNS server:"
    echo
    green " 1. Mosdns configuration rules are complicated"
    green " 2. Mosdns-cn, easy to configure, equivalent to the simplified version of Mosdns configuration recommended"
    echo
    read -r -p "Please select Mosdns or Mosdns-cn, press Enter to install Mosdns-cn by default, please enter pure numbers:" isInstallMosdnsServerInput
    isInstallMosdnsServerInput=${isInstallMosdnsServerInput:-2}

    if [[ "${isInstallMosdnsServerInput}" == "1" ]]; then
        isInstallMosdns="true"
        isinstallMosdnsName="mosdns"
    else
        isInstallMosdns="false"
        isinstallMosdnsName="mosdns-cn"        
    fi

    echo
    green " ================================================== "
    green "Start installing ${isinstallMosdnsName} !"
    green " ================================================== "
    echo
    downloadMosdns


    echo
    green " ================================================== "
    green "Please fill in the port number where mosdns is running. Default port 5335"
    green " DNS server is usually port 53, it is recommended to enter 53"
    yellow "Soft routers generally have built-in DNS servers, if installed in soft routers, the default value is 5335 to avoid conflicts"
    echo
    read -r -p "Please fill in the port number where mosdns is running? The default is 5335, please enter a pure number:" isMosDNSServerPortInput
    isMosDNSServerPortInput=${isMosDNSServerPortInput:-5335}

    mosDNSServerPort="5335"
    reNumber='^[0-9]+$'

    if [[ "${isMosDNSServerPortInput}" =~ ${reNumber} ]] ; then
        mosDNSServerPort="${isMosDNSServerPortInput}"
    fi


    echo
    green " ================================================== "
    green "Whether to add a self-built DNS server, by default, press Enter without adding"
    green "Select to add a DNS server, it is recommended to set up a DNS server before running this script"
    green "This script has built-in multiple DNS server addresses by default"
    echo
    read -r -p "Do you want to add a self-built DNS server? By default, press Enter to not add it, please enter [y/N]:" isAddNewDNSServerInput
    isAddNewDNSServerInput=${isAddNewDNSServerInput:-n}

    addNewDNSServerIPMosdnsCnText=""
    addNewDNSServerDomainMosdnsCnText=""

    addNewDNSServerIPText=""
    addNewDNSServerDomainText=""
    if [[ "$isAddNewDNSServerInput" == [Nn] ]]; then
        echo 
    else
        echo
        green " ================================================== "
        green "Please enter your own DNS server IP format such as 1.1.1.1"
        green "Please ensure that port 53 provides DNS resolution service, if it is a non-port 53, please fill in the port number, the format is for example 1.1.1.1:8053"
        echo
        read -r -p "Please enter the IP address of the self-built DNS server, please enter:" isAddNewDNSServerIPInput

        if [ -n "${isAddNewDNSServerIPInput}" ]; then
            addNewDNSServerIPMosdnsCnText="\"udp://${isAddNewDNSServerIPInput}\", "
            read -r -d '' addNewDNSServerIPText << EOM
        - addr: "udp://${isAddNewDNSServerIPInput}"
          idle_timeout: 500
          trusted: true
EOM

        fi

        echo
        green " ================================================== "
        green "Please enter the domain name of the self-built DNS server to provide DOH service, the format is for example www.dns.com"
        green "Please ensure that the server provides DOH service at /dns-query, eg https://www.dns.com/dns-query"
        echo 
        read -r -p "Please enter the domain name of the self-built DOH server, do not enter https://, please enter the domain name directly:" isAddNewDNSServerDomainInput

        if [ -n "${isAddNewDNSServerDomainInput}" ]; then
            addNewDNSServerDomainMosdnsCnText="\"https://${isAddNewDNSServerDomainInput}/dns-query\", "
            read -r -d '' addNewDNSServerDomainText << EOM
        - addr: "https://${isAddNewDNSServerDomainInput}/dns-query"       
          idle_timeout: 400
          trusted: true
EOM
        fi
    fi


    if [[ "${isInstallMosdns}" == "true" ]]; then

        rm -f "${configMosdnsPath}/config.yaml"

        cat > "${configMosdnsPath}/config.yaml" <<-EOF    

log:
  level: info
  file: "${configMosdnsPath}/mosdns.log"

data_providers:
  - tag: geosite
    file: ${configMosdnsPath}/${geositeFilename}
    auto_reload: true
  - tag: geoip
    file: ${configMosdnsPath}/${geoipFilename}
    auto_reload: true

plugins:
  # cache
  - tag: cache
    type: cache
    args:
      size: 2048
      lazy_cache_ttl: 86400 
      cache_everything: true

  # hosts map
  # - tag: map_hosts
  #   type: hosts
  #   args:
  #     hosts:
  # - 'google.com 0.0.0.0'
  # - 'api.miwifi.com 127.0.0.1'
  # - 'www.baidu.com 0.0.0.0'

  # Forward to the plugin on the local server
  - tag: forward_local
    type: fast_forward
    args:
      upstream:
        - addr: "udp://223.5.5.5"
          idle_timeout: 30
          trusted: true
        - addr: "udp://119.29.29.29"
          idle_timeout: 30
          trusted: true
        - addr: "tls://120.53.53.53:853"
          enable_pipeline: true
          idle_timeout: 30

  # Forward to the plugin on the remote server
  - tag: forward_remote
    type: fast_forward
    args:
      upstream:
${addNewDNSServerIPText}
${addNewDNSServerDomainText}
        #- addr: "tls://8.8.4.4:853"
        #  enable_pipeline: true
        - addr: "udp://208.67.222.222"
          trusted: true
        - addr: "208.67.220.220:443"
          trusted: true   

        #- addr: "udp://172.105.216.54"
        #  idle_timeout: 400
        #  trusted: true 
        - addr: "udp://5.2.75.231"
          idle_timeout: 400
          trusted: true

        - addr: "udp://1.0.0.1"
          trusted: true
        #- addr: "tls://1dot1dot1dot1.cloudflare-dns.com"
        #- addr: "https://dns.cloudflare.com/dns-query"
        
        - addr: "https://doh.apad.pro/dns-query"
          idle_timeout: 400
          trusted: true

        
        - addr: "udp://185.121.177.177"
          idle_timeout: 400
          trusted: true        
        #- addr: "udp://169.239.202.202"


        - addr: "udp://94.130.180.225"
          idle_timeout: 400
          trusted: true  
        - addr: "udp://78.47.64.161"
          idle_timeout: 400
          trusted: true
        #- addr: "tls://dns-dot.dnsforfamily.com"
        #- addr: "https://dns-doh.dnsforfamily.com/dns-query"
        #  dial_addr: "94.130.180.225:443"
        #  idle_timeout: 400

        #- addr: "udp://101.101.101.101"
        #  idle_timeout: 400
        #  trusted: true 
        #- addr: "udp://101.102.103.104"
        #  idle_timeout: 400
        #  trusted: true
        #- addr: "tls://101.101.101.101"
        #- addr: "https://dns.twnic.tw/dns-query"
        #  idle_timeout: 400

        #- addr: "udp://172.104.237.57"

        - addr: "udp://51.38.83.141"          
        #- addr: "tls://dns.oszx.co"
        #- addr: "https://dns.oszx.co/dns-query"
        #  idle_timeout: 400 

        - addr: "udp://176.9.93.198"
        - addr: "udp://176.9.1.117"                  
        #- addr: "tls://dnsforge.de"
        #- addr: "https://dnsforge.de/dns-query"
        #  idle_timeout: 400

        - addr: "udp://88.198.92.222"                  
        #- addr: "tls://dot.libredns.gr"
        #- addr: "https://doh.libredns.gr/dns-query"
        #  idle_timeout: 400

  # Plugins that match local domains
  - tag: query_is_local_domain
    type: query_matcher
    args:
      domain:
        - 'provider:geosite:cn'

  - tag: query_is_gfw_domain
    type: query_matcher
    args:
      domain:
        - 'provider:geosite:gfw'

  # Plugins that match non-local domains
  - tag: query_is_non_local_domain
    type: query_matcher
    args:
      domain:
        - 'provider:geosite:geolocation-!cn'

  # Plugins that match ad domains
  - tag: query_is_ad_domain
    type: query_matcher
    args:
      domain:
        - 'provider:geosite:category-ads-all'

  # Plugins that match local IP
  - tag: response_has_local_ip
    type: response_matcher
    args:
      ip:
        - 'provider:geoip:cn'


  # Main run logic plugin
  # The plug-in tag called in the sequence plug-in must be defined before the sequence,
  # Otherwise sequence cannot find the corresponding plugin.
  - tag: main_sequence
    type: sequence
    args:
      exec:
        # - map_hosts

        # cache
        - cache

        # Block ad domains ad block
        - if: query_is_ad_domain
          exec:
            - _new_nxdomain_response
            - _return

        # Known local domain names are resolved with the local server
        - if: query_is_local_domain
          exec:
            - forward_local
            - _return

        - if: query_is_gfw_domain
          exec:
            - forward_remote
            - _return

        # Known non-local domain names are resolved with remote servers
        - if: query_is_non_local_domain
          exec:
            - _prefer_ipv4
            - forward_remote
            - _return

          # The remaining unknown domain names are distributed by IP.
          # primary gets the answer from the local server, discarding the result of the non-local IP.
        - primary:
            - forward_local
            - if: "(! response_has_local_ip) && [_response_valid_answer]"
              exec:
                - _drop_response
          secondary:
            - _prefer_ipv4
            - forward_remote
          fast_fallback: 200
          always_standby: true

servers:
  - exec: main_sequence
    listeners:
      - protocol: udp
        addr: ":${mosDNSServerPort}"
      - protocol: tcp
        addr: ":${mosDNSServerPort}"

EOF

        ${configMosdnsPath}/mosdns service install -c "${configMosdnsPath}/config.yaml" -d "${configMosdnsPath}" 
        ${configMosdnsPath}/mosdns service start



    else


        rm -f "${configMosdnsPath}/config_mosdns_cn.yaml"

        cat > "${configMosdnsPath}/config_mosdns_cn.yaml" <<-EOF    
server_addr: ":${mosDNSServerPort}"
cache_size: 2048
lazy_cache_ttl: 86400
lazy_cache_reply_ttl: 30
redis_cache: ""
min_ttl: 300
max_ttl: 3600
hosts: []
arbitrary: []
blacklist_domain: []
insecure: false
ca: []
debug: false
log_file: "${configMosdnsPath}/mosdns-cn.log"
upstream: []
local_upstream: ["udp://223.5.5.5", "udp://119.29.29.29"]
local_ip: ["${configMosdnsPath}/${geoipFilename}:cn"]
local_domain: []
local_latency: 50
remote_upstream: [${addNewDNSServerIPMosdnsCnText}  ${addNewDNSServerDomainMosdnsCnText}  "udp://1.0.0.1", "udp://208.67.222.222", "tls://8.8.4.4:853", "udp://5.2.75.231", "udp://172.105.216.54"]
remote_domain: ["${configMosdnsPath}/${geositeFilename}:geolocation-!cn"]
working_dir: "${configMosdnsPath}"
cd2exe: false

EOF

        ${configMosdnsPath}/mosdns-cn --service install --config "${configMosdnsPath}/config_mosdns_cn.yaml" --dir "${configMosdnsPath}" 

        ${configMosdnsPath}/mosdns-cn --service start
    fi

    echo 
    green " =================================================="
    green " ${isinstallMosdnsName} successfully installed! Running port: ${mosDNSServerPort}"
    echo
    green "Start: systemctl start ${isinstallMosdnsName} Stop: systemctl stop ${isinstallMosdnsName}"  
    green "Restart: systemctl restart ${isinstallMosdnsName}"
    green " View status: systemctl status ${isinstallMosdnsName} "
    green "View log: journalctl -n 50 -u ${isinstallMosdnsName} "
    green "View access log: cat ${configMosdnsPath}/${isinstallMosdnsName}.log"

    # green "Start command: ${configMosdnsPath}/${isinstallMosdnsName} -s start -dir ${configMosdnsPath} "
    # green "Stop command: ${configMosdnsPath}/${isinstallMosdnsName} -s stop -dir ${configMosdnsPath} "
    # green "Restart command: ${configMosdnsPath}/${isinstallMosdnsName} -s restart -dir ${configMosdnsPath} "
    green " =================================================="

}

function removeMosdns(){
    if [[ -f "${configMosdnsPath}/mosdns" || -f "${configMosdnsPath}/mosdns-cn" ]]; then
        if [[ -f "${configMosdnsPath}/mosdns" ]]; then
            isInstallMosdns="true"
            isinstallMosdnsName="mosdns"
        fi

        if [ -f "${configMosdnsPath}/mosdns-cn" ]; then
            isInstallMosdns="false"
            isinstallMosdnsName="mosdns-cn"
        fi

        echo
        green " =================================================="
        green "Ready to uninstall installed ${isinstallMosdnsName}"
        green " =================================================="
        echo

        if [[ "${isInstallMosdns}" == "true" ]]; then
            ${configMosdnsPath}/${isinstallMosdnsName} service stop
            ${configMosdnsPath}/${isinstallMosdnsName} service uninstall
        else
            ${configMosdnsPath}/mosdns-cn --service stop
            ${configMosdnsPath}/mosdns-cn --service uninstall

        fi

        rm -rf "${configMosdnsPath}"

        echo
        green " ================================================== "
        green " ${isinstallMosdnsName} is uninstalled!"
        green " ================================================== "

    else
        echo
        red "Mosdns is not installed in the system, exit to uninstall"
        echo
    fi

}











configAdGuardPath="/opt/AdGuardHome"

# DNS server 
function installAdGuardHome(){
	wget -qN --no-check-certificate -O ./ad_guard_install.sh https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh && chmod +x ./ad_guard_install.sh && ./ad_guard_install.sh -v
    echo
    if [[ ${configLanguage} == "cn" ]] ; then
        green " To uninstall and remove AdGuard Home run the command ./ad_guard_install.sh -u"
        green "Please open the URL http://yourip:3000 to complete the initial configuration"
        green "After completing initialization, please re-run this script and select 29 to obtain an SSL certificate. Enable DOH and DOT"
    else
        green " Remove AdGuardHome, pls run ./ad_guard_install.sh -u "
        green " Please open http://yourip:3000 and complete the initialization "
        green " After the initialization, pls rerun this script and choose 29 to get SSL certificate "
    fi
    echo
}

function getAdGuardHomeSSLCertification(){
    if [ -f "${configAdGuardPath}/AdGuardHome" ]; then
        echo
        green " =================================================="
        green "Detected that AdGuard Home is installed"
        green " Found AdGuard Home have already installed"
        echo
        green "Continue to apply for SSL certificate, Continue to get Free SSL certificate ?"
        read -p "Whether to apply for an SSL certificate, please enter [Y/n]:" isGetAdGuardSSLCertificateInput
        isGetAdGuardSSLCertificateInput=${isGetAdGuardSSLCertificateInput:-Y}

        if [[ "${isGetAdGuardSSLCertificateInput}" == [Yy] ]]; then
            ${configAdGuardPath}/AdGuardHome -s stop
            configSSLCertPath="${configSSLCertPath}/adguardhome"
            renewCertificationWithAcme ""
            replaceAdGuardConfig
        fi
    fi
}

function replaceAdGuardConfig(){

    if [ -f "${configAdGuardPath}/AdGuardHome" ]; then
        
        if [ -f "${configAdGuardPath}/AdGuardHome.yaml" ]; then
            echo
            yellow "Prepare to fill in the applied SSL certificate into the AdGuardHome configuration file"
            yellow " prepare to get SSL certificate and replace AdGuardHome config"

            # https://stackoverflow.com/questions/4396974/sed-or-awk-delete-n-lines-following-a-pattern
            sed -i -e '/^tls:/{n;d}' ${configAdGuardPath}/AdGuardHome.yaml
            sed -i "/^tls:/a \  enabled: true" ${configAdGuardPath}/AdGuardHome.yaml
            # sed -i 's/enabled: false/enabled: true/g' ${configAdGuardPath}/AdGuardHome.yaml

            sed -i "s/server_name: .*/server_name: ${configSSLDomain}/g" ${configAdGuardPath}/AdGuardHome.yaml
            sed -i "s|certificate_path: .*|certificate_path: ${configSSLCertPath}/${configSSLCertFullchainFilename}|g" ${configAdGuardPath}/AdGuardHome.yaml
            sed -i "s|private_key_path: .*|private_key_path: ${configSSLCertPath}/${configSSLCertKeyFilename}|g" ${configAdGuardPath}/AdGuardHome.yaml

            # Enable DNS parallel query acceleration
            sed -i 's/all_servers: false/all_servers: true/g' ${configAdGuardPath}/AdGuardHome.yaml


            read -r -d '' adGuardConfigUpstreamDns << EOM
  - 1.0.0.1
  - https://dns.cloudflare.com/dns-query
  - 8.8.8.8
  - https://dns.google/dns-query
  - tls://dns.google
  - 9.9.9.9
  - https://dns.quad9.net/dns-query
  - tls://dns.quad9.net
  - 208.67.222.222
  - https://doh.opendns.com/dns-query
EOM
            TEST1="${adGuardConfigUpstreamDns//\\/\\\\}"
            TEST1="${TEST1//\//\\/}"
            TEST1="${TEST1//&/\\&}"
            TEST1="${TEST1//$'\n'/\\n}"

            sed -i "/upstream_dns:/a \  ${TEST1}" ${configAdGuardPath}/AdGuardHome.yaml


            read -r -d '' adGuardConfigBootstrapDns << EOM
  - 1.0.0.1 
  - 8.8.8.8
  - 8.8.4.4
EOM
            TEST2="${adGuardConfigBootstrapDns//\\/\\\\}"
            TEST2="${TEST2//\//\\/}"
            TEST2="${TEST2//&/\\&}"
            TEST2="${TEST2//$'\n'/\\n}"

            sed -i "/bootstrap_dns:/a \  ${TEST2}" ${configAdGuardPath}/AdGuardHome.yaml


            read -r -d '' adGuardConfigFilters << EOM
- enabled: true
  url: https://anti-ad.net/easylist.txt
  name: 'CHN: anti-AD'
  id: 1652375944
- enabled: true
  url: https://easylist-downloads.adblockplus.org/easylistchina.txt
  name: EasyList China
  id: 1652375945
EOM
            # https://fabianlee.org/2018/10/28/linux-using-sed-to-insert-lines-before-or-after-a-match/

            TEST3="${adGuardConfigFilters//\\/\\\\}"
            TEST3="${TEST3//\//\\/}"
            TEST3="${TEST3//&/\\&}"
            TEST3="${TEST3//$'\n'/\\n}"

            sed -i "/id: 2/a ${TEST3}" ${configAdGuardPath}/AdGuardHome.yaml


            echo
            green " AdGuard Home config updated success: ${configAdGuardPath}/AdGuardHome.yaml "
            green "AdGuard Home configuration file updated successfully: ${configAdGuardPath}/AdGuardHome.yaml "
            echo
            ${configAdGuardPath}/AdGuardHome -s restart
        else
            red "The AdGuardHome configuration file ${configAdGuardPath}/AdGuardHome.yaml is not detected, please complete the AdGuardHome initialization configuration first"
            red " ${configAdGuardPath}/AdGuardHome.yaml not found, pls complete the AdGuardHome initialization first!"
        fi 

    else
        red "AdGuard Home not found, Please install AdGuard Home first !"
    fi

}


































function firewallForbiden(){
    # firewall-cmd --permanent --direct --add-rule ipv4 filter OUTPUT 0 -p tcp -m tcp --dport=25 -j ACCEPT
    # firewall-cmd --permanent --direct --add-rule ipv4 filter OUTPUT 1 -p tcp -m tcp --dport=25 -j REJECT
    # firewall-cmd --reload

    firewall-cmd --permanent --direct --add-rule ipv4 filter OUTPUT 0 -p tcp -m tcp --dport=25 -j DROP
    firewall-cmd --permanent --direct --add-rule ipv4 filter OUTPUT 1 -j ACCEPT
    firewall-cmd --reload

    # iptables -A OUTPUT -p tcp --dport 25 -j DROP

    # iptables -A INPUT -p tcp -s 0/0 -d 0/0 --dport 80 -j DROP
    # iptables -A INPUT -p all -j ACCEPT
    # iptables -A OUTPUT -p all -j ACCEPT
}





function startMenuOther(){
    clear

    if [[ ${configLanguage} == "cn" ]] ; then
    
    green " =================================================="
    red "You cannot use this script or other scripts to install trojan or v2ray before installing the following 3 visual management panels! "
    red "If you have installed trojan or v2ray, please uninstall or redo a clean system first! 3 admin panels cannot be installed at the same time"
    echo
    green " 1. Install trojan-web (trojan and trojan-go visual admin panels) and nginx masquerading site"
    green " 2. Upgrade trojan-web to the latest version"
    green " 3. Reapply for a certificate"
    green " 4. View logs, manage users, view configuration and other functions"
    red " 5. Uninstall trojan-web and nginx "
    echo
    green " 6. Install V2ray visual management panel V2-UI, which can support trojan at the same time"
    green " 7. Upgrade V2-UI to the latest version"
    red " 8. Uninstall V2-UI"
    echo
    green " 9. Install Xray visual management panel X-UI, can support trojan at the same time"
    red " 10. Upgrade or uninstall X-UI"
    echo
    green " =================================================="
    red "The following is a VPS network speed test tool, script speed test will consume a lot of VPS traffic, please be aware!"
    green " 41. superspeed three-network pure speed measurement (full speed measurement of some nodes of the three major operators across the country) is recommended"
    green " 42. yet-another-bench-script comprehensive test (including CPU IO test international multiple data node network speed test) is recommended"
    green " 43. Bench comprehensive test written by teddysun (including system information IO test domestic multiple data node network speed test)"
	green " 44. LemonBench fast all-round test (including CPU memory performance, backhaul, node speed test) "
    green " 45. ZBench comprehensive network speed test (including node speed test, ping and routing test)"
    green " 46. testrace backhaul routing test by nanqinlang (four network routing Shanghai Telecom Xiamen Telecom Zhejiang Hangzhou Unicom Zhejiang Hangzhou Mobile Beijing Education Network)"
    green " 47. autoBestTrace backhaul routing test (Guangzhou Telecom Shanghai Telecom Xiamen Telecom Chongqing Unicom Chengdu Unicom Shanghai Mobile Chengdu Mobile Chengdu Education Network)"
    green " 48. Recommended for backhaul routing test (Beijing Telecom/Unicom/Mobile Shanghai Telecom/Unicom/Mobile Guangzhou Telecom/Unicom/Mobile)"
    green " 49. Three network backhaul routing test Go language development by zhanghanyun "   
    green " 50. Standalone server tests include system info and I/O tests"
    echo
    green " =================================================="
    green " 51. Test whether the VPS supports Netflix non-produced drama unblocking support WARP sock5 test, recommended"
    green " 52. Test whether the VPS supports Netflix, the Go language version is recommended by sjlleo, recommended"
    green " 53. Test if VPS supports Netflix, Disney, Hulu and more streaming platforms, new version by lmc999"
    #green " 54. Test whether the VPS supports Netflix, check the IP unblocking range and the corresponding region, the original version by CoiaPrant"

    echo
    green " 61. Install official pagoda panels"
    green " 62. Install the pure version of the pagoda panel by hostcli.com"
    green " 63. Install the pagoda panel cracked version 7.9 by yu.al"
    echo
    green " 99. Return to previous menu"
    green " 0. Exit script"    

    else

    
    green " =================================================="
    red " Install 3 UI admin panel below require clean VPS system. Cannot install if VPS already installed trojan or v2ray "
    red " Pls remove trojan or v2ray if installed. Prefer using clean system to install UI admin panel. "
    red " Trojan and v2ray UI admin panel cannot install at the same time."
    echo
    green " 1. install trojan-web (trojan/trojan-go UI admin panel) with nginx"
    green " 2. upgrade trojan-web to latest version"
    green " 3. redo to request SSL certificate if you got problem with SSL"
    green " 4. Show log and config, manage users, etc."
    red " 5. remove trojan-web and nginx"
    echo
    green " 6. install  V2-UI admin panel, support trojan protocal"
    green " 7. upgrade V2-UI to latest version"
    red " 8. remove V2-UI"
    echo
    green " 9. install X-UI admin panel, support trojan protocal"
    red " 10. upgrade or remove X-UI"
    echo
    green " =================================================="
    red " VPS speedtest tools. Pay attention that speed tests will consume lots of traffic."
    green " 41. superspeed. ( China telecom / China unicom / China mobile node speed test ) "
    green " 42. yet-another-bench-script ( CPU IO Memory Network speed test)"
    green " 43. Bench by teddysun"
	green " 44. LemonBench ( CPU IO Memory Network Traceroute test） "
    green " 45. ZBench "
    green " 46. testrace by nanqinlang (four network routes Shanghai Telecom Xiamen Telecom Zhejiang Hangzhou Unicom Zhejiang Hangzhou Mobile Beijing Education Network)"
    green " 47. autoBestTrace (Traceroute test Guangzhou Telecom Shanghai Telecom Xiamen Telecom Chongqing Unicom Chengdu Unicom Shanghai Mobile Chengdu Mobile Chengdu Education Network)"
    green " 48. returnroute test (Beijing Telecom/Unicom/Mobile Shanghai Telecom/Unicom/Mobile Guangzhou Telecom/Unicom/Mobile)"
    green " 49. returnroute test by zhanghanyun powered by Go (three networks return route test) "    
    green " 50. A bench script for dedicated servers "    
    echo
    green " =================================================="
    green " 51. Netflix region and non-self produced drama unlock test, support WARP SOCKS5 proxy and IPv6"
    green " 52. Netflix region and non-self produced drama unlock test by sjlleo using go language."
    green " 53. Netflix, Disney, Hulu etc unlock test by by lmc999"
    #green " 54. Netflix region and non-self produced drama unlock test by CoiaPrant"
    echo
    green " 61. install official bt panel (aa panel)"
    green " 62. install modified bt panel (aa panel) by hostcli.com"
    green " 63. install modified bt panel (aa panel) 7.9 by yu.al"
    echo
    green " 99. Back to main menu"
    green " 0. exit"


    fi


    echo
    read -p "Please input number:" menuNumberInput
    case "$menuNumberInput" in
        1 )
            setLinuxDateZone
            configInstallNginxMode="trojanWeb"
            installTrojanWeb
        ;;
        2 )
            upgradeTrojanWeb
        ;;
        3 )
            runTrojanWebGetSSL
        ;;
        4 )
            runTrojanWebCommand
        ;;
        5 )
            removeNginx
            removeTrojanWeb
        ;;
        6 )
            setLinuxDateZone
            installV2rayUI
        ;;
        7 )
            upgradeV2rayUI
        ;;
        8 )
            removeV2rayUI
        ;;
        9 )
            setLinuxDateZone
            installXUI
        ;;
        10 )
            removeXUI
        ;;                                        
        41 )
            vps_superspeed
        ;;
        42 )
            vps_yabs
        ;;        
        43 )
            vps_bench
        ;;
        44 )
            vps_LemonBench
        ;;
        45 )
            vps_zbench
        ;;
        46 )
            vps_testrace
        ;;
        47 )
            vps_autoBestTrace
        ;;
        48 )
            vps_returnroute
            vps_returnroute2
        ;;
        49 )
            vps_returnroute2
        ;;                
        50 )
            vps_bench_dedicated
        ;;        
        51 )
            vps_netflix_jin
        ;;
        52 )
            vps_netflixgo
        ;;
        53 )
            vps_netflix2
        ;;
        54 )
            vps_netflix2
        ;;
        61 )
            installBTPanel
        ;;
        62 )
            installBTPanelCrackHostcli
        ;;
        63 )
            installBTPanelCrack
        ;;
        81 )
            installBBR
        ;;
        82 )
            installBBR2
        ;;
        99)
            start_menu
        ;;
        0 )
            exit 1
        ;;
        * )
            clear
            red "Please enter the correct number!"
            sleep 2s
            startMenuOther
        ;;
    esac
}

























function start_menu(){
    clear

    if [[ $1 == "first" ]] ; then
        getLinuxOSRelease
        installSoftDownload
    fi

    if [[ ${configLanguage} == "cn" ]] ; then

    green " ===================================================================================================="
    green "Trojan Trojan-go V2ray Xray One-Click Install Script | 2022-8-15 | System Support: centos7+/debian9+/ubuntu16.04+"
    green " ===================================================================================================="
    green " 1. Install linux kernel bbr plus, install WireGuard, for unblocking Netflix restrictions and avoiding pop-up Google reCAPTCHA human verification"
    echo
    green " 2. Install trojan or trojan-go and nginx, CDN is not supported, trojan or trojan-go runs on port 443"
    green " 3. Install trojan-go and nginx, support CDN to open websocket, trojan-go runs on port 443"
    green " 4. Only install trojan or trojan-go running on 443 or custom port, do not install nginx, easy to integrate with existing website or pagoda panel"
    green " 5. Upgrade trojan or trojan-go to the latest version"
    red "6. Uninstall trojan or trojan-go and nginx"
    echo
    green " 11. Install v2ray or xray and nginx ([Vmess/Vless]-[TCP/WS/gRPC/H2/QUIC]-TLS), support CDN, nginx runs on port 443"
    green " 12. Only install v2ray or xray ([Vmess/Vless]-[TCP/WS/gRPC/H2/QUIC]), no TLS encryption, easy to integrate with existing websites or pagoda panels"
    echo
    green " 13. Install v2ray or xray (VLess-TCP-[TLS/XTLS])+(VMess-TCP-TLS)+(VMess-WS-TLS) support CDN, optionally install nginx, VLess runs on port 443"
    green " 14. Install v2ray or xray (VLess-gRPC-TLS) to support CDN, optionally install nginx, VLess runs on port 443"
    green " 15. Install v2ray or xray (VLess-TCP-[TLS/XTLS])+(VLess-WS-TLS) support CDN, optionally install nginx, VLess runs on port 443"
    #green " 16. Install v2ray or xray (VLess-TCP-[TLS/XTLS])+(VLess-WS-TLS)+(VLess-gRPC-TLS) support CDN, optionally install nginx, VLess runs on port 443"
    green " 17. Install v2ray or xray (VLess-TCP-[TLS/XTLS])+(VLess-WS-TLS)+xray's own trojan, support CDN, optionally install nginx, VLess runs on port 443"  
    green " 18. Upgrade v2ray or xray to the latest version"
    red " 19. Uninstall v2ray or xray and nginx"
    echo
    green " 21. Install v2ray or xray and trojan or trojan-go (VLess-TCP-[TLS/XTLS])+(VLess-WS-TLS)+Trojan at the same time, support CDN, optionally install nginx, VLess runs on port 443 "  
    green " 22. Install nginx, v2ray or xray and trojan or trojan-go (VLess/Vmess-WS-TLS)+Trojan at the same time, support CDN, trojan or trojan-go run on port 443"  
    green " 23. Install nginx, v2ray or xray and trojan or trojan-go at the same time, offload through nginx SNI, support CDN, support coexistence with existing websites, nginx runs on port 443"
    red " 24. Uninstall trojan, v2ray or xray and nginx"
    echo
    green " 25. View information such as installed configuration and user password"
    green " 26. Apply for a free SSL certificate"
    green " 30. Submenu install trojan and v2ray visual management panel, VPS speed test tool, Netflix test unlock tool, install pagoda panel, etc."
    green " =================================================="
    green " 31. Install DNS server AdGuardHome to support de-advertising"
    green " 32. Apply for a free SSL certificate for AdGuardHome, and enable DOH and DOT"    
    green " 33. Install DNS domestic and foreign shunting server mosdns or mosdns-cn"    
    red "34. Uninstall mosdns or mosdns-cn DNS server"
    echo
    green " 41. Install OhMyZsh and plug-in zsh-autosuggestions, Micro editor and other software"
    green " 42. Enable root user SSH login. For example, Google Cloud disables root login by default, you can use this option to enable it"
    green " 43. Modify the SSH login port number"
    green " 44. Set the time zone to Beijing time"
    green " 45. Use VI to edit the authorized_keys file and fill in the public key for SSH password-free login to increase security"
    echo
    green " 88. Upgrade script"
    green " 0. Exit script"

    else


    green " ===================================================================================================="
    green " Trojan Trojan-go V2ray Xray Installation | 2022-8-15 | OS support: centos7+ / debian9+ / ubuntu16.04+"
    green " ===================================================================================================="
    green " 1. Install linux kernel,  bbr plus kernel, WireGuard and Cloudflare WARP. Unlock Netflix geo restriction and avoid Google reCAPTCHA"
    echo
    green " 2. Install trojan/trojan-go with nginx, not support CDN acceleration, trojan/trojan-go running at 443 port serve TLS"
    green " 3. Install trojan-go with nginx, enable websocket, support CDN acceleration, trojan-go running at 443 port serve TLS"
    green " 4. Install trojan/trojan-go only, trojan/trojan-go running at 443(can customize port) serve TLS. Easy integration with existing website"
    green " 5. Upgrade trojan/trojan-go to latest version"
    red " 6. Remove trojan/trojan-go and nginx"
    echo
    green " 11. Install v2ray/xray with nginx, ([Vmess/Vless]-[TCP/WS/gRPC/H2/QUIC]-TLS), support CDN acceleration, nginx running at 443 port serve TLS"
    green " 12. Install v2ray/xray only. ([Vmess/Vless]-[TCP/WS/gRPC/H2/QUIC]), no TLS encryption. Easy integration with existing website"
    echo
    green " 13. Install v2ray/xray (VLess-TCP-[TLS/XTLS])+(VMess-TCP-TLS)+(VMess-WS-TLS), support CDN, nginx is optional, VLess running at 443 port serve TLS"
    green " 14. Install v2ray/xray (VLess-gRPC-TLS) support CDN, nginx is optional, VLess running at 443 port serve TLS"
    green " 15. Install v2ray/xray (VLess-TCP-[TLS/XTLS])+(VLess-WS-TLS) support CDN, nginx is optional, VLess running at 443 port serve TLS"

    green " 17. Install v2ray/xray (VLess-TCP-[TLS/XTLS])+(VLess-WS-TLS)+(xray's trojan), support CDN, nginx is optional, VLess running at 443 port serve TLS"
    green " 18. Upgrade v2ray/xray to latest version"
    red " 19. Remove v2ray/xray and nginx"
    echo
    green " 21. Install both v2ray/xray and trojan/trojan-go (VLess-TCP-[TLS/XTLS])+(VLess-WS-TLS)+Trojan, support CDN, nginx is optional, VLess running at 443 port serve TLS"
    green " 22. Install both v2ray/xray and trojan/trojan-go with nginx, (VLess/Vmess-WS-TLS)+Trojan, support CDN, trojan/trojan-go running at 443 port serve TLS"
    green " 23. Install both v2ray/xray and trojan/trojan-go with nginx. Using nginx SNI distinguish traffic by different domain name, support CDN. Easy integration with existing website. nginx SNI running at 443 port"
    red " 24. Remove trojan/trojan-go, v2ray/xray and nginx"
    echo
    green " 25. Show info and password for installed trojan and v2ray"
    green " 26. Get a free SSL certificate for one or multiple domains"
    green " 30. Submenu. install trojan and v2ray UI admin panel, VPS speedtest tools, Netflix unlock tools. Miscellaneous tools"
    green " =================================================="
    green " 31. Install AdGuardHome, ads & trackers blocking DNS server "
    green " 32. Get free SSL certificate for AdGuardHome and enable DOH/DOT "
    green " 33. Install DNS server MosDNS/MosDNS-cn"
    red " 34. Remove DNS server MosDNS/MosDNS-cn"

    echo
    green " 41. Install Oh My Zsh and zsh-autosuggestions plugin, Micro editor"
    green " 42. Enable root user login SSH, Some VPS disable root login as default, use this option to enable"
    green " 43. Modify SSH login port number. Secure your VPS"
    green " 44. Set timezone to Beijing time"
    green " 45. Using VI open authorized_keys file, enter your public key. Then save file. In order to login VPS without Password"
    echo
    green " 88. upgrade this script to latest version"
    green " 0. exit"

    fi


    echo
    read -p "Please input number:" menuNumberInput
    case "$menuNumberInput" in
        1 )
            installWireguard
        ;;
        2 )
            configInstallNginxMode="noSSL"
            installTrojanV2rayWithNginx "trojan_nginx"
        ;;
        3 )
            configInstallNginxMode="noSSL"
            isTrojanGoSupportWebsocket="true"
            installTrojanV2rayWithNginx "trojan_nginx"
        ;;
        4 )
            installTrojanV2rayWithNginx "trojan"
        ;;
        5 )
            upgradeTrojan
        ;;
        6 )
            removeTrojan
            removeNginx
        ;;
        11 )
            configInstallNginxMode="v2raySSL"
            configV2rayWorkingMode=""
            installTrojanV2rayWithNginx "nginx_v2ray"
        ;;
        12 )
            configInstallNginxMode=""
            configV2rayWorkingMode=""
            installTrojanV2rayWithNginx "v2ray"
        ;;
        13 )
            configInstallNginxMode="noSSL"
            configV2rayWorkingMode="vlessTCPVmessWS"
            installTrojanV2rayWithNginx "v2ray_nginxOptional"
        ;;
        14 )
            configInstallNginxMode="noSSL"
            configV2rayWorkingMode="vlessgRPC"
            installTrojanV2rayWithNginx "v2ray_nginxOptional"
        ;;
        15 )
            configInstallNginxMode="noSSL"
            configV2rayWorkingMode="vlessTCPWS"
            installTrojanV2rayWithNginx "v2ray_nginxOptional"
        ;;
        16 )
            configInstallNginxMode="noSSL"
            configV2rayWorkingMode="vlessTCPWSgRPC"
            installTrojanV2rayWithNginx "v2ray_nginxOptional"
        ;;
        17 )
            configInstallNginxMode="noSSL"
            configV2rayWorkingMode="vlessTCPWSTrojan"
            installTrojanV2rayWithNginx "v2ray_nginxOptional"
        ;; 
        18)
            upgradeV2ray
        ;;
        19 )
            removeV2ray
            removeNginx
        ;;
        21 )
            configInstallNginxMode="noSSL"
            configV2rayWorkingMode="trojan"
            installTrojanV2rayWithNginx "v2ray_nginxOptional"
        ;;
        22 )
            configInstallNginxMode="noSSL"
            configV2rayWorkingMode=""
            configV2rayWorkingNotChangeMode="true"
            installTrojanV2rayWithNginx "trojan_nginx_v2ray"
        ;;
        23 )
            configInstallNginxMode="sni"
            configV2rayWorkingMode="sni"
            installTrojanV2rayWithNginx "nginxSNI_trojan_v2ray"
        ;;
        24 )
            removeV2ray
            removeTrojan
            removeNginx
        ;;
        25 )
            cat "${configReadme}"
        ;;        
        26 )
            installTrojanV2rayWithNginx
        ;;
        30 )
            startMenuOther
        ;;
        31 )
            installAdGuardHome
        ;;
        32 )
            getAdGuardHomeSSLCertification "$@"
        ;;        
        33 )
            installMosdns
        ;;        
        34 )
            removeMosdns
        ;;
        41 )
            setLinuxDateZone
            installPackage
            installSoftEditor
            installSoftOhMyZsh
        ;;
        42 )
            setLinuxRootLogin
            sleep 4s
            start_menu
        ;;
        43 )
            changeLinuxSSHPort
            sleep 10s
            start_menu
        ;;
        44 )
            setLinuxDateZone
            sleep 4s
            start_menu
        ;;
        45 )
            editLinuxLoginWithPublicKey
        ;;


        66 )
            isTrojanMultiPassword="yes"
            echo "isTrojanMultiPassword: yes"
            sleep 3s
            start_menu
        ;;
        76 )
            vps_returnroute
            vps_returnroute2
        ;;
        77 )
            vps_netflixgo
            vps_netflix_jin
        ;;
        80 )
            installPackage
        ;;
        81 )
            installBBR
        ;;
        82 )
            installBBR2
        ;;
        84 )
            firewallForbiden
        ;;        
        88 )
            upgradeScript
        ;;
        99 )
            getTrojanAndV2rayVersion "trojan"
            getTrojanAndV2rayVersion "trojan-go"
            getTrojanAndV2rayVersion "trojan-web"
            getTrojanAndV2rayVersion "v2ray"
            getTrojanAndV2rayVersion "xray"
            getTrojanAndV2rayVersion "wgcf"
        ;;
        0 )
            exit 1
        ;;
        * )
            clear
            red "Please enter the correct number!"
            sleep 2s
            start_menu
        ;;
    esac
}





function setLanguage(){
    echo
    green " =================================================="
    green " Please choose your language"
    green " 1. Chinese"
    green " 2. English"  
    echo
    read -p "Please input your language:" languageInput
    
    case "${languageInput}" in
        1 )
            echo "cn" > ${configLanguageFilePath}
            showMenu
        ;;
        2 )
            echo "en" > ${configLanguageFilePath}
            showMenu
        ;;
        * )
            red " Please input the correct number !"
            setLanguage
        ;;
    esac

}

configLanguageFilePath="${HOME}/language_setting_v2ray_trojan.md"
configLanguage="cn"

function showMenu(){

    if [ -f "${configLanguageFilePath}" ]; then
        configLanguage=$(cat ${configLanguageFilePath})

        case "${configLanguage}" in
        cn )
            start_menu "first"
        ;;
        in )
            start_menu "first"
        ;;
        * )
            setLanguage
        ;;
        esac
    else
        installPackage
        setLanguage
    fi
}

showMenu