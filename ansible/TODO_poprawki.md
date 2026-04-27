# Tematy do poprawki — VXLAN EVPN Ansible

## Krytyczne

- [ ] **Poświadczenia w plaintext** — `inventory/hosts.yml` zawiera `ansible_ssh_pass: admin` i `ansible_become_password: admin` bezpośrednio w pliku. Przenieść do ansible-vault lub zmiennych środowiskowych (`ANSIBLE_NET_PASSWORD`).

- [ ] **Niedziałający `site.yml`** — odwołuje się do roli `inzynierka.evpn_eos.run`, która nie istnieje. Usunąć plik lub zastąpić go poprawnym odwołaniem do `inzynierka.evpn_eos.vxlan_base`.

- [ ] **Brak `arista.eos` w `collections/requirements.yml`** — główna zależność projektu nie jest zadeklarowana. Dodać wpis z wersją zgodną z używanymi modułami.

- [ ] **Brak idempotentności w konfiguracji BGP** — `setup_bgp.yml` zaczyna od `no router bgp {{ bgp_asn }}`, co przy każdym uruchomieniu powoduje przerwę w działaniu sieci. Przepisać z użyciem modułów resource (`arista.eos.bgp_global` ze stanem `replaced`) zamiast surowych komend `config`.

## Umiarkowane

- [ ] **Kruche numerowanie sąsiadów BGP na spinach** — mapowanie `Ethernet{{ idx+1 }}` → `remote-as 6510{{ idx+1 }}` oparte na `loop_control.index_var` jest wrażliwe na zmianę kolejności interfejsów. Rozważyć jawne mapowanie interfejs→ASN w `host_vars` spajny.

- [ ] **Osierocony plik `setup_vxlan_interface.yml`** — leży w `roles/vxlan_base/` ale nie jest importowany przez `main.yml`. Usunąć lub zintegrować z resztą roli.

- [ ] **`validate_certs: false` bez komentarza** — dodać komentarz w `hosts.yml` wyjaśniający, że to środowisko labowe z self-signed cert (cEOS).

- [ ] **Nieużywana kolekcja `cisco.ios`** — zadeklarowana w `requirements.yml`, ale żaden playbook jej nie używa. Usunąć.

## Kosmetyczne

- [ ] **Usunąć niezwiązane pliki szablonów** — `linux_playbook.yml`, `argspec_validation_plays.yml`, `argspec_validation_plays.meta.yml`, `argspec_validation_inventory.yml` to niezmodyfikowane pliki z generatora projektu, niepowiązane z VXLAN.

- [ ] **Dodać `.logs/` do `.gitignore`** — artefakty ansible-navigator nie powinny być śledzone przez git.

- [ ] **Dodać tagi do tasków** — umożliwi selektywne uruchamianie np. `--tags bgp` lub `--tags vlans` bez modyfikacji kodu.

- [ ] **Dodać testy Molecule** — standardem dla kolekcji Ansible jest katalog `molecule/` z testami weryfikującymi idempotentność roli.
