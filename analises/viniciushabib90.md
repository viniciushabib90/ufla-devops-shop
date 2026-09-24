# Autopsia: Cloudflare (02/07/2019)

**Autor:** Vinicius Habib Andrade (@viniciushabib90)
**Fonte primaria:** https://blog.cloudflare.com/details-of-the-cloudflare-outage-on-july-2-2019/
**Data de acesso:** 28/08/2026

## 1. O que aconteceu

Em 2 de julho de 2019, a Cloudflare colocou no ar uma nova regra de segurança que fez os processadores dos servidores trabalharem excessivamente. O problema começou às 13:42 UTC e, poucos minutos depois, os sistemas de monitoramento começaram a indicar falhas. Às 14:00, a equipe identificou que o problema estava relacionado ao sistema de proteção. Às 14:07, a regra foi desativada em toda a rede e, dois minutos depois, o tráfego e o uso dos processadores voltaram ao normal. O problema durou cerca de 27 minutos.

## 2. Qual das Tres Vias falhou

**Fluxo** — O principal problema estava na forma como a mudança era levada até os servidores. A Cloudflare já utilizava um processo de implantação gradual para seus softwares, mas as regras do sistema de proteção podiam ser distribuídas globalmente de uma vez. Isso fez com que uma mudança com problema atingisse praticamente toda a rede ao mesmo tempo. O relatório mostra que esse tipo de alteração não passava pelo mesmo processo gradual utilizado para outras mudanças de software.

## 3. Quais metricas DORA teriam denunciado antes

A métrica que mais poderia indicar o risco seria a **Change Failure Rate**, pois uma quantidade elevada de mudanças que causassem problemas mostraria que o processo precisava de mais controles. No caso da Cloudflare, havia muitas alterações nas regras de proteção e o processo permitia que uma mudança problemática fosse distribuída rapidamente para toda a rede.

A **Deployment Frequency** também poderia ajudar a identificar o risco. A frequência de alterações, por si só, não é um problema, mas muitas mudanças feitas sem uma forma segura de limitar o impacto aumentam a possibilidade de uma falha atingir muitos usuários. O relatório informa que, nos 60 dias anteriores ao incidente, foram tratados 476 pedidos de alteração nas regras, uma média de aproximadamente uma alteração a cada três horas. Esse número mostrava que mudanças desse tipo eram frequentes e, por isso, precisavam de mecanismos que limitassem o impacto de uma alteração incorreta.

## 4. Qual pratica do semestre teria evitado -- e em que semana

A prática que poderia ter evitado o incidente é a **implantação gradual (canary)**, apresentada na **Semana 8**. Em vez de disponibilizar a nova regra para toda a rede de uma vez, ela seria aplicada primeiro a uma pequena parte dos servidores. Seria possível observar o comportamento da mudança e interrompê-la caso surgissem problemas. No caso da Cloudflare, isso teria limitado o impacto da regra que causou o uso excessivo dos processadores e evitado que a falha atingisse praticamente toda a rede.

## 5. A cultura do relatorio: generativa ou patologica?

Considero a cultura da Cloudflare **generativa**, pois o relatório procura entender o que aconteceu no processo e no sistema, em vez de simplesmente responsabilizar a pessoa que fez a mudança. Isso fica claro quando a empresa afirma: **"Everything that occurred up to the point the rules were deployed was done 'correctly'"**. A partir disso, o relatório procura identificar os fatores que permitiram que a falha acontecesse e apresenta mudanças no processo para evitar que problemas semelhantes ocorram novamente.
