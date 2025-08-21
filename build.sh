cd upstream && git checkout main && cd ..
cp build.sh ./upstream/
git apply patches/*.patch || true
cd upstream
./mach bootstrap --application-choice browser
MOZCONFIG=$PWD/mozconfig/release.mozconfig ./mach build
