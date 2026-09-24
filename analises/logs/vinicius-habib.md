# Analise de access.log -- Vinicius Habib Andrade (@viniciushabib90)

**Linhas analisadas:** 516866

## 1. Quantas requisições deram erro?

### Pipeline

```bash
awk '{
    total++
    if ($9 >= 400 && $9 < 500) quatro++
    if ($9 >= 500 && $9 < 600) cinco++
}
END {
    printf "Total: %d\n4xx: %d (%.2f%%)\n5xx: %d (%.2f%%)\n", total, quatro, quatro/total*100, cinco, cinco/total*100
}' dados/access.log
```

### Saída

```text
Total: 516866
4xx: 6162 (1,19%)
5xx: 11749 (2,27%)
```

### Interpretação

Foram analisadas 516.866 requisições. Dessas, 6.162 (1,19%) resultaram em erros 4xx, enquanto 11.749 (2,27%) resultaram em erros 5xx. Os erros 5xx representam uma parcela maior que os 4xx, indicando que os problemas internos do servidor merecem atenção prioritária.

## 2. Quais IPs mais fizeram requisições?

### Pipeline

```bash
awk '{print $1}' dados/access.log | sort | uniq -c | sort -rn | awk 'NR<=10'
```

### Saída

```text
  88400 203.0.113.47
   1788 192.0.2.245
   1772 192.0.2.171
   1771 192.0.2.81
   1771 192.0.2.225
   1771 192.0.2.16
   1767 192.0.2.138
   1762 192.0.2.222
   1757 192.0.2.45
   1753 192.0.2.166
```

O IP `203.0.113.47` se destaca significativamente, com 88.400 requisições, enquanto o segundo colocado possui 1.788. Portanto, esse IP merece investigação.

### Investigação do IP suspeito

**Endpoints mais acessados:**

```bash
awk '$1=="203.0.113.47" {print $7}' dados/access.log | sort | uniq -c | sort -rn | awk 'NR<=10'
```

```text
  22224 /api/busca?q=mochila
  22161 /api/busca?q=tenis
  22090 /api/busca?q=camiseta
  21925 /api/busca?q=fone
```

**User-Agent:**

```bash
awk '$1=="203.0.113.47" {print $12}' dados/access.log | sort | uniq -c | sort -rn
```

```text
  88400 "curl/8.5.0"
```

**Maior taxa de requisições por minuto:**

```bash
awk '$1=="203.0.113.47" {print $4}' dados/access.log | cut -d: -f1-3 | sort | uniq -c | sort -rn | awk 'NR<=10'
```

```text
   1021 [14/Aug/2026:23:44
   1017 [14/Aug/2026:23:00
   1015 [14/Aug/2026:23:32
   1007 [14/Aug/2026:23:21
   1002 [14/Aug/2026:23:17
    995 [14/Aug/2026:23:53
    994 [14/Aug/2026:23:33
    993 [14/Aug/2026:23:28
    992 [14/Aug/2026:23:55
    991 [14/Aug/2026:23:22
```

### Interpretação

O IP `203.0.113.47` apresenta comportamento suspeito: realizou 88.400 requisições, concentradas em apenas quatro consultas da API `/api/busca`, utilizando exclusivamente o User-Agent `curl/8.5.0`. Além disso, chegou a realizar 1.021 requisições em um único minuto, aproximadamente 17 requisições por segundo, o que indica um provável acesso automatizado ou *bot* realizando consultas repetitivas.

## 3. Qual caminho causou mais erros 500?

### Pipeline para identificar o endpoint

```bash
awk '$9==500 {print $7}' dados/access.log | sort | uniq -c | sort -rn | awk 'NR<=10'
```

### Saída

```text
   3620 /api/relatorio/gerar
    228 /
    167 /api/produtos
    160 /produtos
    150 /produtos/detalhe
    117 /static/app.css
    105 /static/app.js
     92 /api/carrinho
     63 /api/busca
     44 /favicon.ico
```

O endpoint `/api/relatorio/gerar` foi o que mais apresentou erros 500, com 3.620 ocorrências.

### Verificação da frequência de falha

```bash
awk '$7=="/api/relatorio/gerar" {
    total++
    if ($9==500) erros++
}
END {
    printf "Total de requisicoes: %d\nErros 500: %d\nPercentual de 500: %.2f%%\n", total, erros, erros/total*100
}' dados/access.log
```

### Saída

```text
Total de requisicoes: 10400
Erros 500: 3620
Percentual de 500: 34,81%
```

### Interpretação

O endpoint `/api/relatorio/gerar` recebeu 10.400 requisições e apresentou 3.620 erros 500, correspondendo a 34,81% das requisições. Portanto, o endpoint não quebra sempre, mas apresenta uma taxa de falha elevada, com aproximadamente uma em cada três requisições resultando em erro interno do servidor.

## 4. Qual horário teve maior tráfego?

### Pipeline

```bash
awk '{print $4}' dados/access.log | cut -d: -f2 | sort | uniq -c | sort -k2n
```

### Saída

```text
   3262 00
   1967 01
   1810 02
   1471 03
   1498 04
   1844 05
   3904 06
   9759 07
  19519 08
  27621 09
  30869 10
  32526 11
  31895 12
  29952 13
  31225 14
  32529 15
  30886 16
  28575 17
  25996 18
  22807 19
  18860 20
  15577 21
  43979 22
  68535 23
```

### Interpretação

O maior volume de tráfego ocorreu às 23h, com 68.535 requisições. O segundo maior volume ocorreu às 22h, com 43.979 requisições. A distribuição mostra crescimento significativo do tráfego a partir das 07h, mantendo-se elevado durante o dia e apresentando um forte pico entre 22h e 23h.

## 5. Houve tentativas de acesso a caminhos sensíveis?

Foram consideradas tentativas de acesso aos caminhos `/admin`, `.env`, `.git`, `wp-login` e `/phpmyadmin`.

### Número total de tentativas

```bash
awk '$7 ~ /^\/admin/ || $7 ~ /\.env/ || $7 ~ /\.git/ || $7 ~ /wp-login/ || $7 ~ /^\/phpmyadmin/ {c++} END {print c}' dados/access.log
```

### Saída

```text
2080
```

Foram identificadas 2.080 tentativas de acesso aos caminhos considerados sensíveis.

### Número de IPs distintos

```bash
awk '$7 ~ /^\/admin/ || $7 ~ /\.env/ || $7 ~ /\.git/ || $7 ~ /wp-login/ || $7 ~ /^\/phpmyadmin/ {print $1}' dados/access.log | sort -u | wc -l
```

### Saída

```text
2
```

As tentativas foram originadas por 2 IPs distintos.

### Códigos de resposta

```bash
awk '$7 ~ /^\/admin/ || $7 ~ /\.env/ || $7 ~ /\.git/ || $7 ~ /wp-login/ || $7 ~ /^\/phpmyadmin/ {print $9}' dados/access.log | sort | uniq -c | sort -rn
```

### Saída

```text
   2080 404
```

### Interpretação

Foram identificadas 2.080 tentativas de acesso a caminhos sensíveis, originadas por apenas 2 IPs distintos. Todas receberam resposta 404, indicando que os recursos procurados não foram encontrados no servidor. O padrão é compatível com tentativas de sondagem ou busca automatizada por recursos administrativos, arquivos de configuração ou páginas conhecidas, mas os dados analisados não indicam que esses recursos tenham sido encontrados.

## Conclusão: minha primeira ação como operador de plantão

Minha primeira ação como operador de plantão seria **bloquear temporariamente o IP `203.0.113.47`**. Esse endereço realizou 88.400 requisições, muito acima dos demais IPs, utilizando exclusivamente o User-Agent `curl/8.5.0` e chegando a mais de 1.000 requisições por minuto. As requisições ficaram concentradas em apenas quatro consultas da API de busca, indicando um comportamento automatizado e potencialmente abusivo. O bloqueio temporário reduziria imediatamente essa carga enquanto o incidente é escalado para investigação. Paralelamente, o endpoint `/api/relatorio/gerar` deveria ser investigado, pois apresentou 3.620 erros 500 em 10.400 requisições, uma taxa de falha de 34,81%.
