package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net"
	"os"
	"os/exec"
)

// CNI конфігурація
type NetConf struct {
	CNIVersion string `json:"cniVersion"`
	Name       string `json:"name"`
	Type       string `json:"type"`
	Bridge     string `json:"bridge"`
	MTU        int    `json:"mtu"`
	Subnet     string `json:"subnet"`
	Gateway    string `json:"gateway"`
	IPAM       struct {
		Type    string `json:"type"`
		Subnet  string `json:"subnet"`
		Gateway string `json:"gateway"`
	} `json:"ipam,omitempty"`
}

// CNI аргументи
type CmdArgs struct {
	ContainerID string
	Netns       string
	IfName      string
	Args        string
	Path        string
	StdinData   []byte
}

// Результат CNI
type CNIResult struct {
	CNIVersion string `json:"cniVersion"`
	Interfaces []struct {
		Name string `json:"name"`
		Mac  string `json:"mac"`
	} `json:"interfaces"`
	IPs []struct {
		Version string `json:"version"`
		Address string `json:"address"`
		Gateway string `json:"gateway"`
	} `json:"ips"`
	Routes []struct {
		Dst string `json:"dst"`
		GW  string `json:"gw"`
	} `json:"routes"`
}

func main() {
	if len(os.Args) < 2 {
		log.Fatal("Usage: simple-cni <add|del|check>")
	}

	command := os.Args[1]

	// Читаємо конфігурацію з stdin
	var stdinData []byte
	if stat, _ := os.Stdin.Stat(); (stat.Mode() & os.ModeCharDevice) == 0 {
		stdinData, _ = io.ReadAll(os.Stdin)
	}

	// Парсимо аргументи
	args := parseArgs()

	switch command {
	case "add":
		if err := cmdAdd(args, stdinData); err != nil {
			log.Fatal(err)
		}
	case "del":
		if err := cmdDel(args, stdinData); err != nil {
			log.Fatal(err)
		}
	case "check":
		if err := cmdCheck(args, stdinData); err != nil {
			log.Fatal(err)
		}
	default:
		log.Fatal("Unknown command:", command)
	}
}

// cmdAdd виконується коли Kubernetes додає под до мережі
func cmdAdd(args *CmdArgs, stdinData []byte) error {
	log.Printf("ADD: ContainerID=%s, Netns=%s, IfName=%s", args.ContainerID, args.Netns, args.IfName)

	// Парсимо конфігурацію
	conf := &NetConf{}
	if err := json.Unmarshal(stdinData, conf); err != nil {
		return fmt.Errorf("failed to parse config: %v", err)
	}

	// Створюємо мережевий інтерфейс
	if err := createInterface(args, conf); err != nil {
		return err
	}

	// Налаштовуємо IP адресу
	if err := configureIP(args, conf); err != nil {
		return err
	}

	// Отримуємо мережеві налаштування з конфігурації
	subnet := conf.Subnet
	gateway := conf.Gateway

	// Якщо не вказано в основній конфігурації, беремо з IPAM
	if subnet == "" && conf.IPAM.Subnet != "" {
		subnet = conf.IPAM.Subnet
	}
	if gateway == "" && conf.IPAM.Gateway != "" {
		gateway = conf.IPAM.Gateway
	}

	// Значення за замовчуванням
	if subnet == "" {
		subnet = "10.244.0.0/16"
	}
	if gateway == "" {
		gateway = "10.244.0.1"
	}

	// Генеруємо IP адресу для поду
	podIP := generatePodIP(subnet, args.ContainerID)

	// Повертаємо результат
	result := &CNIResult{
		CNIVersion: "1.0.0",
		Interfaces: []struct {
			Name string `json:"name"`
			Mac  string `json:"mac"`
		}{
			{
				Name: args.IfName,
				Mac:  "00:11:22:33:44:55",
			},
		},
		IPs: []struct {
			Version string `json:"version"`
			Address string `json:"address"`
			Gateway string `json:"gateway"`
		}{
			{
				Version: "4",
				Address: podIP,
				Gateway: gateway,
			},
		},
		Routes: []struct {
			Dst string `json:"dst"`
			GW  string `json:"gw"`
		}{
			{
				Dst: "0.0.0.0/0",
				GW:  gateway,
			},
		},
	}

	// Виводимо результат в JSON
	resultJSON, _ := json.MarshalIndent(result, "", "  ")
	fmt.Println(string(resultJSON))

	return nil
}

// cmdDel виконується коли Kubernetes видаляє под з мережі
func cmdDel(args *CmdArgs, stdinData []byte) error {
	log.Printf("DEL: ContainerID=%s, Netns=%s, IfName=%s", args.ContainerID, args.Netns, args.IfName)

	// Парсимо конфігурацію
	conf := &NetConf{}
	if err := json.Unmarshal(stdinData, conf); err != nil {
		return fmt.Errorf("failed to parse config: %v", err)
	}

	// Видаляємо мережевий інтерфейс
	if err := deleteInterface(args, conf); err != nil {
		return err
	}

	return nil
}

// cmdCheck перевіряє стан мережевого інтерфейсу
func cmdCheck(args *CmdArgs, stdinData []byte) error {
	log.Printf("CHECK: ContainerID=%s, Netns=%s, IfName=%s", args.ContainerID, args.Netns, args.IfName)
	return nil
}

// createInterface створює мережевий інтерфейс
func createInterface(args *CmdArgs, conf *NetConf) error {
	// Створюємо veth пару
	vethName := fmt.Sprintf("veth%s", args.ContainerID[:8])
	peerName := args.IfName

	log.Printf("Creating veth pair: %s <-> %s", vethName, peerName)

	// Виконуємо команди для створення veth пари
	cmds := []string{
		fmt.Sprintf("ip link add %s type veth peer name %s", vethName, peerName),
		fmt.Sprintf("ip link set %s netns %s", peerName, args.Netns),
		fmt.Sprintf("ip link set %s up", vethName),
	}

	for _, cmd := range cmds {
		log.Printf("Executing: %s", cmd)
		if err := exec.Command("sh", "-c", cmd).Run(); err != nil {
			log.Printf("Warning: failed to execute %s: %v", cmd, err)
		}
	}

	// Налаштовуємо інтерфейс всередині контейнера
	nsCmds := []string{
		fmt.Sprintf("ip link set %s up", peerName),
	}

	if conf.MTU > 0 {
		nsCmds = append(nsCmds, fmt.Sprintf("ip link set %s mtu %d", peerName, conf.MTU))
	}

	for _, cmd := range nsCmds {
		nsCmd := fmt.Sprintf("nsenter -t %s -n %s", getPIDFromNetns(args.Netns), cmd)
		log.Printf("Executing in namespace: %s", nsCmd)
		if err := exec.Command("sh", "-c", nsCmd).Run(); err != nil {
			log.Printf("Warning: failed to execute in namespace %s: %v", cmd, err)
		}
	}

	return nil
}

// configureIP налаштовує IP адресу
func configureIP(args *CmdArgs, conf *NetConf) error {
	// Отримуємо мережеві налаштування
	subnet := conf.Subnet
	gateway := conf.Gateway

	if subnet == "" && conf.IPAM.Subnet != "" {
		subnet = conf.IPAM.Subnet
	}
	if gateway == "" && conf.IPAM.Gateway != "" {
		gateway = conf.IPAM.Gateway
	}

	if subnet == "" {
		subnet = "10.244.0.0/16"
	}
	if gateway == "" {
		gateway = "10.244.0.1"
	}

	// Генеруємо IP адресу для поду
	podIP := generatePodIP(subnet, args.ContainerID)

	// Додаємо IP адресу до інтерфейсу
	ipCmd := fmt.Sprintf("ip addr add %s dev %s", podIP, args.IfName)
	nsCmd := fmt.Sprintf("nsenter -t %s -n %s", getPIDFromNetns(args.Netns), ipCmd)

	log.Printf("Adding IP address: %s", nsCmd)
	if err := exec.Command("sh", "-c", nsCmd).Run(); err != nil {
		log.Printf("Warning: failed to add IP: %v", err)
	}

	// Додаємо маршрут за замовчуванням
	routeCmd := fmt.Sprintf("ip route add default via %s dev %s", gateway, args.IfName)
	nsRouteCmd := fmt.Sprintf("nsenter -t %s -n %s", getPIDFromNetns(args.Netns), routeCmd)

	log.Printf("Adding default route: %s", nsRouteCmd)
	if err := exec.Command("sh", "-c", nsRouteCmd).Run(); err != nil {
		log.Printf("Warning: failed to add route: %v", err)
	}

	return nil
}

// deleteInterface видаляє мережевий інтерфейс
func deleteInterface(args *CmdArgs, conf *NetConf) error {
	// Видаляємо veth інтерфейс
	vethName := fmt.Sprintf("veth%s", args.ContainerID[:8])

	log.Printf("Deleting veth interface: %s", vethName)

	// Видаляємо інтерфейс з хоста
	cmd := fmt.Sprintf("ip link delete %s", vethName)
	if err := exec.Command("sh", "-c", cmd).Run(); err != nil {
		log.Printf("Warning: failed to delete interface %s: %v", vethName, err)
	}

	return nil
}

// parseArgs парсить аргументи командного рядка
func parseArgs() *CmdArgs {
	args := &CmdArgs{}

	// Парсимо змінні середовища
	args.ContainerID = os.Getenv("CNI_CONTAINERID")
	args.Netns = os.Getenv("CNI_NETNS")
	args.IfName = os.Getenv("CNI_IFNAME")
	args.Args = os.Getenv("CNI_ARGS")
	args.Path = os.Getenv("CNI_PATH")

	// Якщо змінні середовища порожні, спробуємо отримати з аргументів командного рядка
	if args.ContainerID == "" && len(os.Args) > 2 {
		args.ContainerID = os.Args[2]
	}
	if args.Netns == "" && len(os.Args) > 3 {
		args.Netns = os.Args[3]
	}
	if args.IfName == "" && len(os.Args) > 4 {
		args.IfName = os.Args[4]
	}

	return args
}

// generatePodIP генерує IP адресу для поду на основі subnet та containerID
func generatePodIP(subnet, containerID string) string {
	// Парсимо subnet
	_, ipNet, err := net.ParseCIDR(subnet)
	if err != nil {
		log.Printf("Warning: invalid subnet %s, using default", subnet)
		return "10.244.0.10/24"
	}

	// Отримуємо базову IP адресу
	baseIP := ipNet.IP.To4()
	if baseIP == nil {
		log.Printf("Warning: invalid IPv4 subnet %s", subnet)
		return "10.244.0.10/24"
	}

	// Генеруємо IP на основі containerID (хеш)
	hash := 0
	for _, char := range containerID {
		hash = (hash*31 + int(char)) % 254
	}

	// Використовуємо третій октет для різноманітності
	baseIP[2] = byte(hash + 1) // +1 щоб уникнути 0

	// Повертаємо IP з маскою
	mask, _ := ipNet.Mask.Size()
	return fmt.Sprintf("%s/%d", baseIP.String(), mask)
}

// getPIDFromNetns отримує PID процесу з мережевого простору імен
func getPIDFromNetns(netns string) string {
	// Простий спосіб - використовуємо перший PID з netns
	// В реальному CNI це робиться більш складно
	return "1" // Спрощено для демонстрації
}
