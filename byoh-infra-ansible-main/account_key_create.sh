#!/bin/bash

# === 설정 ===
TARGETS="10.12.44.21 10.12.44.22 10.12.44.23"   # <- 대상 서버 IP(공백구분)
GAIA_USER="gaia_test"
SSH_KEY_PATH="$HOME/.ssh/gaia_test_id_rsa"
SSH_PUB_PATH="$SSH_KEY_PATH.pub"

# === 1. SSH 키 생성 ===
if [ -f "$SSH_KEY_PATH" ]; then
    echo "[!] $SSH_KEY_PATH already exists."
    read -p "재생성하려면 yes 입력, 아니면 엔터: " answer
    if [ "$answer" = "yes" ]; then
        rm -f "$SSH_KEY_PATH" "$SSH_PUB_PATH"
        ssh-keygen -t rsa -b 4096 -C "awx-gaia-test" -f "$SSH_KEY_PATH" -N ""
    else
        echo "기존 키 사용"
    fi
else
    ssh-keygen -t rsa -b 4096 -C "awx-gaia-test" -f "$SSH_KEY_PATH" -N ""
fi

# === 2. 각 서버 계정생성, 공개키 등록 ===
for TARGET in $TARGETS; do
    echo "===== $TARGET 서버 작업 시작 ====="

    # 1) 계정 생성(존재하면 패스)
    ssh root@$TARGET "id $GAIA_USER 2>/dev/null || (useradd -m -s /bin/bash $GAIA_USER && echo '계정 생성 완료')"

    # 2) .ssh/authorized_keys 생성 및 키 등록
    PUB_KEY=$(cat "$SSH_PUB_PATH")
    ssh root@$TARGET "
        mkdir -p /home/$GAIA_USER/.ssh
        echo '$PUB_KEY' >> /home/$GAIA_USER/.ssh/authorized_keys
        chown -R $GAIA_USER:$GAIA_USER /home/$GAIA_USER/.ssh
        chmod 700 /home/$GAIA_USER/.ssh
        chmod 600 /home/$GAIA_USER/.ssh/authorized_keys
    "

    # 3) sudo 권한 부여
    ssh root@$TARGET "usermod -aG sudo $GAIA_USER"

    # 4) sudoers 파일 설정 (NOPASSWD)
    ssh root@$TARGET "echo '$GAIA_USER ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$GAIA_USER && chmod 440 /etc/sudoers.d/$GAIA_USER"
done

# === 3. 접속 테스트 ===
for TARGET in $TARGETS; do
    echo ">>> $TARGET 접속 테스트"
    ssh -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" $GAIA_USER@$TARGET "hostname; whoami; sudo -l"
done

echo "=== 모든 서버에 계정/키 등록, sudo NOPASSWD 적용 및 접속 확인 완료 ==="
echo ""
echo "AWX Credential 등록 시 아래 키 파일을 사용하세요:"
echo "  Private Key: $SSH_KEY_PATH"
