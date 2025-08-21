  cd upstream && git checkout main && cd ..
  git apply patches/*.patch || true
  ./mach bootstrap --application-choice browser
  MOZCONFIG=$PWD/mozconfig/release.mozconfig ./mach build
