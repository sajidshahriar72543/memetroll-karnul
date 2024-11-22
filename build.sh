#!/bin/bash

# Replace with your kernel link and branch
# KT_LINK=https://github.com/ihsanulrahman/android_kernel_xiaomi_sm6250 #your_kernel_link
# KT_BRANCH=15.0 #your_branch

# git clone $KT_LINK -b $KT_BRANCH kernel --depth=1 --single-branch
# cd kernel

tg(){
        msg=$2
	curl -s "https://api.telegram.org/bot$BOTID/sendmessage" --data "text=$msg&chat_id=$TGID&parse_mode=html"
}
tg $TGID "kernel compile status: triggered!"

# Setting up ccache
export CCACHE_DIR=/tmp/ccache
export CCACHE_EXEC=$(which ccache)
export USE_CCACHE=1
ccache -M 10G
ccache -o compression=true
ccache -z

# Cloning clang
if ! [ -d "$HOME/cosmic" ]; then
echo "Clang not found! Cloning..."
if ! git clone https://bitbucket.org/shuttercat/clang --depth=1 -b 15 ~/cosmic; then
echo "Cloning failed! Aborting..."
exit 1
fi
fi

SECONDS=0 # builtin bash timer
ZIPNAME="MEMETROLL_KSU-$(date '+%Y%m%d-%H%M').zip" #your_kernel_name
DEFCONFIG="vendor/xiaomi/miatoll_defconfig" #your_defconfig

export PATH="$HOME/cosmic/bin:$PATH"
export ARCH=arm64
export KBUILD_BUILD_USER=ihsanulrahman #your_name
export KBUILD_COMPILER_STRING="$($HOME/cosmic/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"

echo -e "\nStarting compilation...\n"

mkdir -p out
make O=out
make $DEFCONFIG O=out

# To use these you have to use the given flags
if [[ $1 = "-c" || $1 = "--clean" ]]; then
	rm -rf out
fi

if [[ $1 = "-r" || $1 = "--regen" ]]; then
	make O=out ARCH=arm64 $DEFCONFIG savedefconfig
	cp out/defconfig arch/arm64/configs/$DEFCONFIG
	exit 1
fi

# make -j$(nproc --all) O=out ARCH=arm64 CC=clang LLVM=1 LLVM_IAS=1 LD=ld.lld CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi-
# Build the kernel with log output to file
make -j$(nproc --all) O=out ARCH=arm64 CC=clang LLVM=1 LLVM_IAS=1 LD=ld.lld CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- | tee build.log

if [ -f "out/arch/arm64/boot/Image.gz" ]; then
	echo -e "\nKernel compiled succesfully! Zipping up...\n"
	if ! git clone -q  https://github.com/ihsanulrahman/AnyKernel3 -b udc; then #your_anykernel3_fork
		echo -e "\nCloning AnyKernel3 repo failed! Aborting..."
		exit 1
	fi
	cp out/arch/arm64/boot/Image.gz AnyKernel3
	cp out/arch/arm64/boot/dtbo.img AnyKernel3
	cp out/arch/arm64/boot/dts/qcom/cust-atoll-ab.dtb AnyKernel3/dtb
	rm -f ./*zip
	cd AnyKernel3 || exit
	rm -rf out/arch/arm64/boot
	zip -r9 "../$ZIPNAME" ./* -x '*.git*' README.md ./*placeholder
	cd ..
	rm -rf AnyKernel3
	echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
	echo "Zip: $ZIPNAME"
	curl -F document=@"$ZIPNAME" "https://api.telegram.org/bot$BOTID/sendDocument" -F chat_id="$TGID" -F "parse_mode=Markdown" -F caption="*✅ Build finished after $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s)*"
	echo
else
	echo -e "\nCompilation failed!"
    tg $TGID "kernel compile status: failed!"
    # send logs
    curl -F document=@"build.log" "https://api.telegram.org/bot$BOTID/sendDocument" -F chat_id="$TGID" -F "parse_mode=Markdown" -F caption="*❌ Build failed after $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s)*"
fi