# Fluxo ALTP / MAPP — diagramas

> Atenção: nenhum diagrama usa parênteses pra evitar bug do Mermaid.

---

## 1. Visão geral — quem produz e quem consome cada arquivo

```mermaid
flowchart TB
    %% Atores externos ao batch Unix
    CHUCK[Chuck Fears<br/>analista Windows<br/>roda Combine_Stage.bat]
    ANALYST[Analista de Dados<br/>revisa arquivos<br/>via WinSCP]
    NAPA[NAPA Supplier<br/>upload via sftp]
    SUPP[Outros Suppliers<br/>recebem relatorios]

    %% Batch Unix - 3 estagios em cadeia
    subgraph BATCH[Batch Unix - cadeia XAMR]
        direction TB
        REF[XAMR100 / xamref.ksh<br/>REFORMAT - le combined, gera refproc]
        UPD[XAMR101 / xamupd.ksh<br/>UPDATE - le refproc, gera rpt_prov]
        RPT[XAMR102 / xamrpt.ksh<br/>REPORT - le rpt_prov, gera ZIP]
    end

    %% Arquivos por categoria
    subgraph EXT_IN[ARQUIVOS QUE ENTRAM NO BATCH]
        F_COMB[keystone_combined.txt<br/>do Chuck]
        F_NAPA[Mitchell_CollisionFromNAPA.zip<br/>da NAPA direto]
        F_HDR[COL.hdr / COLNW.hdr<br/>do Chuck - estatico]
        F_DEL[del_supplier_list.txt / copy_supplier.txt / capacert.prn<br/>do analista]
    end

    subgraph ROUND[ARQUIVOS ROUND-TRIP - PROBLEMA DE DESIGN]
        F_REF[*_refproc.txt<br/>batch escreve, analista edita, batch le]
        F_PROV[*_rpt_prov.txt<br/>batch escreve, analista edita, batch le]
    end

    subgraph EXT_OUT[ARQUIVOS QUE SAEM DO BATCH]
        F_INT[Internal_Rpts<br/>referrs / refsum / partver_sum / updt_sum]
        F_CUST[Customer_Rpts<br/>category.rpt]
        F_ZIP[mitch_exc_rpts.zip<br/>vai pros suppliers]
    end

    %% Producoes
    CHUCK --> F_COMB
    CHUCK --> F_HDR
    CHUCK --> F_DEL
    NAPA --> F_NAPA

    %% Consumos primeira leva
    F_COMB --> REF
    F_NAPA --> REF
    F_HDR --> REF
    F_DEL --> REF

    %% Round-trip - este é o ponto sensivel
    REF --> F_REF
    F_REF -.->|edita| ANALYST
    ANALYST -.->|devolve| F_REF
    F_REF --> UPD

    UPD --> F_PROV
    F_PROV -.->|edita| ANALYST
    ANALYST -.->|devolve| F_PROV
    F_PROV --> RPT

    %% Saidas
    REF --> F_INT
    UPD --> F_INT
    RPT --> F_INT
    REF --> F_CUST
    RPT --> F_ZIP
    F_ZIP --> SUPP
    F_INT --> ANALYST
    F_CUST --> ANALYST

    classDef extActor fill:#ffe4b5,stroke:#cc7a00,color:#000
    classDef batchNode fill:#b5d8ff,stroke:#0066cc,color:#000
    classDef fileExtIn fill:#c8e6c9,stroke:#2e7d32,color:#000
    classDef fileRound fill:#ffcdd2,stroke:#c62828,color:#000
    classDef fileExtOut fill:#e1bee7,stroke:#7b1fa2,color:#000

    class CHUCK,ANALYST,NAPA,SUPP extActor
    class REF,UPD,RPT batchNode
    class F_COMB,F_NAPA,F_HDR,F_DEL fileExtIn
    class F_REF,F_PROV fileRound
    class F_INT,F_CUST,F_ZIP fileExtOut
```

> Legenda: **laranja** = ator externo (humano/supplier), **azul** = passo do batch, **verde** = arquivo que ENTRA no batch, **vermelho** = arquivo round-trip que vai e volta (problema de design), **roxo** = arquivo que SAI do batch.

---

## 2. Detalhamento do round-trip — fluxo Keystone XAMR100 → 101 → 102

> Esse é o ponto crucial pra decidir onde colocar `_refproc.txt` e `_rpt_prov.txt` no novo modelo.

```mermaid
flowchart LR
    CHUCK[Chuck]
    ANL[Analista]

    subgraph BATCH[Batch Unix]
        direction TB
        R100[XAMR100<br/>xamref]
        R101[XAMR101<br/>xamupd]
        R102[XAMR102<br/>xamrpt]
    end

    subgraph PASTA[Pasta UNICA hoje em prod3nt - altp/]
        direction TB
        FC[keystone_combined.txt]
        FR[keystone_refproc.txt]
        FP[keystone_rpt_prov.txt]
    end

    %% Etapas numeradas para sequenciar
    CHUCK -->|1 PUT| FC
    FC -->|2 GET| R100
    R100 -->|3 PUT| FR
    FR -->|4 GET para revisar| ANL
    ANL -->|5 PUT revisado| FR
    FR -->|6 GET| R101
    R101 -->|7 PUT| FP
    FP -->|8 GET para revisar| ANL
    ANL -->|9 PUT revisado| FP
    FP -->|10 GET| R102
    R102 -->|11 envia para suppliers| OUT[ZIP por email/FTP]

    classDef rt fill:#ffcdd2,stroke:#c62828,color:#000
    class FR,FP rt
```

> Os arquivos em **vermelho** são os "round-trip" — escritos pelo batch, editados pelo analista no MESMO lugar, lidos de volta pelo batch.
> Hoje funciona porque tudo mora em `${NOVELL}altp` — uma pasta só.
> No modelo novo com `incoming` e `outgoing` separados, a pergunta é: **onde mora o `refproc.txt`**? Se `outgoing/`, o analista precisa mover pra `incoming/` antes do XAMR101 rodar. Se `incoming/`, o analista trabalha sempre no mesmo lugar como hoje.

---

## 3. Comparacao prod3nt HOJE vs Mitchell FTP DEPOIS

```mermaid
flowchart TB
    subgraph HOJE[HOJE - prod3nt]
        direction TB
        H1[altp/]
        H2[altp/NAPA/]
        H3[altp/Internal_Rpts/]
        H4[altp/Customer_Rpts/]
        H_NOTE[Tudo num lugar so<br/>analista trabalha no mesmo<br/>lugar onde batch le]
    end

    subgraph DEPOIS[DEPOIS - Mitchell FTP]
        direction TB
        D1[altp/incoming/]
        D2[altp/incoming/NAPA/]
        D3[altp/outgoing/]
        D4[altp/outgoing/Internal_Rpts/]
        D5[altp/outgoing/Customer_Rpts/]
        D6[altp/outgoing/NAPA/]
        D7[altp/bakup/]
        D8[altp/bakup/NAPA/]
    end

    H1 -.->|combined.txt + refproc + rpt_prov| D1
    H1 -.->|outgoing - reports gerados| D3
    H2 -.->|headers COL.hdr/COLNW.hdr| D2
    H2 -.->|reformatados col.txt/colnw.txt| D6
    H2 -.->|backup do zip de entrada| D8
    H3 -.->|relatorios internos| D4
    H4 -.->|relatorios para cliente| D5
```

---

## 4. Mapeamento detalhado por arquivo - INTERPRETACAO B recomendada

> Interpretação B = "incoming = trabalho interno entre batch e analista, outgoing = só o que sai pra fora da Mitchell".

```mermaid
flowchart LR
    subgraph SOURCE[Origem]
        S_CHUCK[Chuck<br/>Combine_Stage.bat]
        S_NAPA[NAPA supplier]
        S_BATCH[Batch produz]
    end

    subgraph FILES[Arquivos por categoria]
        FA[combined.txt - external in]
        FB[NAPA zip - external in]
        FC[COL.hdr COLNW.hdr - static]
        FD[del_supplier copy_supplier capacert - external in]
        FE[refproc.txt - round-trip]
        FF[rpt_prov.txt - round-trip]
        FG[col.txt colnw.txt - intermediate]
        FH[napa_combined.txt - intermediate]
        FI[Internal_Rpts - reports]
        FJ[Customer_Rpts - reports]
        FK[mitch_exc_rpts.zip - to supplier]
        FL[CollisionFromNapa.zip cópia - backup]
    end

    subgraph DEST[Destino novo Mitchell FTP]
        D_IN[altp/incoming/]
        D_NAPA_IN[altp/incoming/NAPA/]
        D_OUT_IN[altp/outgoing/Internal_Rpts/]
        D_OUT_CU[altp/outgoing/Customer_Rpts/]
        D_OUT_NAPA[altp/outgoing/NAPA/]
        D_BAK_NAPA[altp/bakup/NAPA/]
        D_NAPA_FTP[NAPA/mdev/incoming<br/>JA EXISTE]
    end

    S_CHUCK --> FA
    S_NAPA --> FB
    S_CHUCK --> FC
    S_CHUCK --> FD
    S_BATCH --> FE
    S_BATCH --> FF
    S_BATCH --> FG
    S_BATCH --> FH
    S_BATCH --> FI
    S_BATCH --> FJ
    S_BATCH --> FK
    S_BATCH --> FL

    FA --> D_IN
    FB --> D_NAPA_FTP
    FC --> D_NAPA_IN
    FD --> D_IN
    FE --> D_IN
    FF --> D_IN
    FG --> D_NAPA_IN
    FH --> D_IN
    FI --> D_OUT_IN
    FJ --> D_OUT_CU
    FK --> D_OUT_NAPA
    FL --> D_BAK_NAPA

    classDef rtClass fill:#ffcdd2,stroke:#c62828,color:#000
    class FE,FF rtClass
```

> Note como na Interpretação B os arquivos round-trip (vermelho) ficam em `incoming/` — mesma pasta que o Chuck escreve. Analista trabalha sempre no mesmo lugar, sem novo passo operacional.

---

## 5. Cadeia de execucao completa - todos os XAMR

```mermaid
flowchart TB
    subgraph KEYSTONE[Cadeia Keystone]
        K100[XAMR100 reformat]
        K101[XAMR101 update]
        K102[XAMR102 report]
        K100 --> K101 --> K102
    end

    subgraph NAPA_CHAIN[Cadeia NAPA]
        N200[XAMR200 reformat]
        N201[XAMR201 update]
        N202[XAMR202 report]
        N200 --> N201 --> N202
    end

    subgraph OTHER[Cadeia Outros suppliers]
        O900[XAMR900 reformat]
        O901[XAMR901 update]
        O902[XAMR902 report]
        O900 --> O901 --> O902
    end

    subgraph SHARED[Scripts auxiliares - rodam fora da cadeia]
        X001[xam001 - del supplier list]
        X030[xam030 - copy supplier]
        X069[xam069 - CAPA load]
        X010[xam010 - extras + reports]
    end

    K100 -.->|usa| XAMREF[xamref.ksh]
    K101 -.->|usa| XAMUPD[xamupd.ksh]
    K102 -.->|usa| XAMRPT[xamrpt.ksh]
    O900 -.->|usa| XAMREF
    O901 -.->|usa| XAMUPD
    O902 -.->|usa| XAMRPT
    N200 -.->|usa| XAM200[xam200.ksh]
    N201 -.->|usa| XAMUPD
    N202 -.->|usa| XAMRPT
```

> Os 3 scripts no fundo - **xamref / xamupd / xamrpt** - são a "máquina" reaproveitada pelas 3 cadeias. Ao editar esses 3, você cobre Keystone, NAPA e os outros suppliers de uma vez. Por isso o `xamref.ksh` é por onde começamos.
