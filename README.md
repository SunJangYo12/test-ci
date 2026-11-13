version 6.40.5 >> telnet 192.168.0.101 8123
	login: devel
	password:

version 6.42.11 >> telnet 192.168.0.101 1270
  NOTE: versi 6.42.11 setelah berjalan dan masuk root dengan telnet akses root tidak
        permanen alias gak bisa akses root lagi setelah reboot

version 6.46.1 >> 
  cd ../../routeros/poc/execute_milo/build
  ../execute_milo -i 192.168.0.101 -u admin
  or
  ../../routeros/poc/execute_milo/build/execute_milo -i 192.168.43.1 -u admin
    [+] Connecting...
    [+] Successful login
    [+] Successfully executed milo
  $ telnet 192.168.0.101 1270
	NOTE: untuk upload binary busybox, etc.. lihat README

version mikrotik-7.20.1_git.iso >
   login: devel
   password:

version chr-7.20.1-legacy-bios_gitpathch.qcow2>
    login: devel
    password:
    NOTE: devel hanya sekali jadi harus cepat diambil snapshot

Transfer GDBSERVER:
    $ python -m http.server 8143
    $ wget http://192.168.0.103:8143/gdbserver.i686

GDB:
 - ./gdbserver.i686 --attach 192.168.43.1:12345 $(pgrep www)
 - cd squashfs
 - gdb nova/bin/www
 - (gdb) target remote 192.168.43.1:12345
 - (gdb) set sysroot squashfs-root/ (opsional)

# IS backuped
chr-6.46.1.qcow2
