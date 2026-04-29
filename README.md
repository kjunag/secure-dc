# Bezpieczne Data Center – Lab VXLAN/EVPN

Laboratoryjne środowisko symulujące produkcyjne centrum danych oparte na architekturze leaf-spine z siecią nakładkową VXLAN i protokołem EVPN jako płaszczyzną sterowania. Projekt obejmuje automatyzację konfiguracji urządzeń sieciowych (Ansible), symulację topologii (Containerlab) oraz testowanie bezpieczeństwa sieci.

## Architektura

Projekt składa się z trzech oddzielnych topologii Containerlab – centrum danych (DC), sieci ISP oraz oddziału biurowego (Office) – połączonych wirtualnymi mostami sieciowymi.


### Centrum danych (DC)

Sieć centrum danych zbudowana jest w oparciu o architekturę **leaf-spine** (Clos), w której każdy przełącznik brzegowy (leaf) jest podłączony do obu przełączników szkieletowych (spine). Dzięki temu każda para urządzeń końcowych ma dokładnie dwie równoważne ścieżki, co eliminuje pętle warstwy drugiej bez potrzeby stosowania STP i zapewnia przewidywalne, niskie opóźnienia.

**Płaszczyzna danych** opiera się na tunelach **VXLAN** (Virtual Extensible LAN). Każda ramka Ethernet wysyłana przez maszynę końcową jest enkapsulowana w pakiet UDP i przesyłana przez sieć IP między przełącznikami leaf pełniącymi rolę VTEP (VXLAN Tunnel Endpoint). Dzięki temu logiczne sieci warstwy drugiej (VLAN-y) mogą rozciągać się ponad fizyczną infrastrukturą warstwy trzeciej, a liczba możliwych segmentów wzrasta z 4096 (VLAN) do ponad 16 milionów (VNI).

**Płaszczyzna sterowania** bazuje na protokole **BGP EVPN** (Ethernet VPN, RFC 7432). Zamiast tradycyjnego rozgłaszania MAC przez flooding, każdy VTEP publikuje informacje o swoich adresach MAC i IP jako trasy BGP rodziny address-family L2VPN EVPN. Spine pełnią rolę Route Reflectorów i redystrybuują te trasy do pozostałych leafów. W efekcie każdy przełącznik leaf zna z góry lokalizację zdalnych hostów, co eliminuje niepotrzebny ruch BUM (Broadcast, Unknown unicast, Multicast) i zmniejsza obciążenie sieci.

**Wielodostępność** (multi-tenancy) realizowana jest przez trzy oddzielne VRF-y – APPS, STORAGE i DMZ – z których każdy ma własną przestrzeń adresową IP, własne trasy BGP i własne VNI. Komunikacja między VRF-ami odbywa się wyłącznie przez klaster zapór sieciowych FortiGate (DC1FW1/FW2 w trybie Active-Passive HA), co umożliwia centralną inspekcję ruchu między strefami.

**Leaf zewnętrzne** (DC1LEAF5, DC1LEAF6) obsługują połączenia z FortiGate przez Port-Channel z konfiguracją Ethernet Segment Identifier (ESI), co zapewnia redundancję multi-homing po stronie firewall bez potrzeby stosowania tradycyjnego MLAG.

### Sieć ISP

ISP symuluje operatora świadczącego dwie usługi równocześnie. **MPLS** zapewnia prywatną, gwarantowaną łączność typu punkt-punkt między DC a Office za pośrednictwem routerów Provider Edge (PE1 dla DC, PE2 dla Office) i rdzenia (P1–P4 w topologii pierścienia). **Internet** udostępniany jest tą samą infrastrukturą fizyczną, ale w oddzielnej płaszczyźnie przekazywania, co pozwala FortiGate po obu stronach nawiązać tunel IPsec ponad publicznym adresowaniem.

### Oddział biurowy (Office)

Architektura sieci biurowej celowo różni się od centrum danych – zamiast VXLAN/EVPN zastosowano klasyczne podejście warstwowe z przełącznikami dystrybucyjnymi i dostępowymi.

**Redundancja** na poziomie dystrybucji realizowana jest przez **MLAG** (Multi-chassis Link Aggregation) między parą przełączników OFF1DISTSW1 i OFF1DISTSW2. Para MLAG prezentuje się dla podłączonych urządzeń jako jeden logiczny przełącznik, dzięki czemu przełączniki dostępowe (OFF1ACCSW1–4) mogą być dual-homed bez ryzyka pętli i bez potrzeby konfigurowania spanning tree na uplinku. Między DISTSW1 a DISTSW2 biegnie dedykowane łącze peer-link (dwa równoległe połączenia), przez które synchronizowany jest stan MLAG i przesyłany jest ruch w przypadku awarii jednego z uplinków.

**Strefa bezpieczeństwa** realizowana jest przez klaster FortiGate (OFF1FW1/OFF1FW2), który terminuje zarówno ruch z ISP, jak i tunel IPsec prowadzący do centrum danych. Dzięki temu cały ruch wchodzący i wychodzący z oddziału przechodzi przez inspekcję zapory, niezależnie od tego, czy pochodzi z internetu, sieci MPLS, czy tunelu IPsec.

### Łączność DC–Office (IPsec przez ISP)

Tunele IPsec zestawiane są między klastrami FortiGate po obu stronach. Ruch między DC a Office jest szyfrowany end-to-end i przesyłany przez infrastrukturę ISP – niezależnie od tego, czy jako transport służy łącze MPLS, czy publiczny internet. Takie podejście zapewnia poufność transmisji nawet wtedy, gdy ISP jest traktowany jako sieć niezaufana.


## Technologie

| Warstwa | Technologia | Szczegóły |
|---------|-------------|-----------|
| Symulacja sieci | Containerlab | Topologie DC, ISP, Office |
| Przełączniki DC | Arista cEOS | 4.35.3F – 2 spine, 6 leaf |
| Przełączniki Office | Arista cEOS | 4.35.3F – 2 dist, 4 access |
| Routery ISP | Cisco IOS XE | 17.12.01 via vrnetlab |
| Przełączniki WAN | Cisco IOS L2 | 17.12.0.1 via vrnetlab |
| Zapora sieciowa | Fortinet FortiOS | 7.2.0 – klaster HA (DC i Office) |
| Nakładka DC | VXLAN + BGP EVPN | RFC 7432, typ 2/5 |
| Redundancja Office | MLAG | Klasyczny multi-chassis LAG |
| Łączność WAN | IPsec + MPLS/Internet | Tunel DC–Office przez ISP |
| Automatyzacja | Ansible | Kolekcja `inzynierka.evpn_eos` |
| Testowanie | Kali Linux | Własny obraz Docker |

## Struktura projektu

```
inzynierka/
├── clab/
│   ├── dc/                      # Topologia centrum danych (leaf-spine, VXLAN/EVPN)
│   │   └── dc.clab.yaml
│   ├── isp/                     # Topologia sieci ISP (MPLS + Internet)
│   │   └── isp.clab.yaml
│   ├── office/                  # Topologia oddziału biurowego (MLAG, bez VXLAN)
│   │   └── office.clab.yaml
│   └── icons/                   # Ikony do wizualizacji
├── ansible/
│   ├── collections/
│   │   └── ansible_collections/
│   │       └── inzynierka/evpn_eos/
│   │           └── roles/vxlan_base/  # Główna rola konfiguracyjna
│   ├── inventory/               # Hosts, zmienne grup i hostów
│   ├── site.yml                 # Główny playbook
│   └── ansible.cfg
├── docker/
│   └── kali-linux/             # Własny obraz testowy
├── Topologies.drawio            # Edytowalny diagram sieci
└── Topologies.svg               # Wizualizacja topologii
```

## Wymagania

### Oprogramowanie

- [Containerlab](https://containerlab.dev/) ≥ 0.56
- Docker Engine
- Python ≥ 3.10
- Ansible ≥ 9.0

### Obrazy kontenerów

Przed uruchomieniem lab należy posiadać obrazy:

```bash
# Arista cEOS (wymaga licencji Arista)
docker import cEOS-lab-4.35.3F.tar.xz ceos:4.35.3F

# Fortinet FortiOS (via vrnetlab)
# Cisco IOS XE (via vrnetlab)
```

## Uruchomienie

### 1. Topologia centrum danych

```bash
cd clab/dc
sudo containerlab deploy -t dc.clab.yaml
```

### 2. Topologia ISP

```bash
cd clab/isp
sudo containerlab deploy -t isp.clab.yaml
```

### 3. Topologia oddziału biurowego

```bash
cd clab/office
sudo containerlab deploy -t office.clab.yaml
```

### 4. Konfiguracja urządzeń (Ansible)

```bash
cd ansible

# Instalacja zależności
ansible-galaxy collection install -r collections/requirements.yml

# Wdrożenie konfiguracji VXLAN/EVPN
ansible-playbook site.yml
```

### 5. Zatrzymanie lab

```bash
sudo containerlab destroy -t clab/dc/dc.clab.yaml
sudo containerlab destroy -t clab/isp/isp.clab.yaml
sudo containerlab destroy -t clab/office/office.clab.yaml
```

## Konfiguracja sieci

### Numery AS (BGP)

| Urządzenie | ASN |
|------------|-----|
| DC1SPINE1, DC1SPINE2 | 65000 |
| DC1LEAF1 | 65101 |
| DC1LEAF2 | 65102 |
| DC1LEAF3 | 65103 |
| DC1LEAF4 | 65104 |
| DC1LEAF5 | 65105 |
| DC1LEAF6 | 65106 |

### Sieci VLAN i VRF

| VRF | VLANy | Przeznaczenie |
|-----|-------|---------------|
| APPS-VRF | 101–104 | Serwery aplikacyjne |
| STORAGE-VRF | 201–204 | Storage / macierze |
| DMZ-VRF | 301–304 | Strefa DMZ |

### Firewall (HA)

Klaster FortiGate działa w trybie Active-Passive. Konfiguracja inicjalna wykonywana jest ręcznie według poleceń w pliku `ansible/fortigates_init_setup`.

## Ansible – kolekcja `inzynierka.evpn_eos`

Rola `vxlan_base` konfiguruje urządzenia Arista EOS w kolejności:

1. **`setup_vlans`** – tworzenie VLAN-ów roboczych i tranzytowych
2. **`create_vrfs`** – konfiguracja VRF z route distinguisher
3. **`basic_setup`** – IPv6, wirtualny MAC (MLAG), SNMPv3
4. **`setup_interfaces`** – interfejsy fabric, loopback, SVI, tunel VXLAN
5. **`setup_bgp`** – BGP, grupy peers, address-family EVPN/IPv4/IPv6
6. **`setup_external_leafs`** – Port-Channel z Ethernet Segment (ESI) dla leaf zewnętrznych

## Testowanie

Węzły `pc1` i `pc2` oparte na Kali Linux umożliwiają testowanie połączeń i bezpieczeństwa między segmentami sieci:

```bash
# Połączenie do węzła testowego
docker exec -it clab-datacenter-pc1 bash

# Przykładowe testy
ping <adres-w-sieci>
iperf3 -s          # serwer
iperf3 -c <ip>     # klient
```

## Diagram topologii

Plik `Topologies.drawio` zawiera edytowalny diagram całej infrastruktury (DC + ISP). Można go otworzyć w [draw.io](https://draw.io) lub bezpośrednio w VS Code z rozszerzeniem Draw.io.

## Licencja

Projekt akademicki – praca inżynierska.
