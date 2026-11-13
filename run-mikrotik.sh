#target="chr-6.46.1.qcow2"
target="$@"

qemu-system-x86_64 \
    -enable-kvm -cpu host -smp 4 -m 15G -machine q35 \
    -hda $target \
    -monitor telnet:127.0.0.1:4544,server,nowait \
    -nographic \
    -device e1000,netdev=net0 \
    -netdev user,id=net0,hostfwd=tcp::8221-:21,hostfwd=tcp::8222-:22,hostfwd=tcp::8223-:23,hostfwd=tcp::8280-:80,hostfwd=tcp::8243-:443,hostfwd=tcp::8391-:8291,hostfwd=tcp::8328-:8728,hostfwd=tcp::8329-:8729,hostfwd=tcp::1370-:1270 -nographic
