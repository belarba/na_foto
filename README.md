# Na Foto

Aplicacao web que analisa fotografias e identifica o que esta na imagem usando segmentacao semantica com IA.

Faz upload de uma foto (ou tira uma diretamente no telemovel) e recebe:

- **Segmentacao semantica** - X% construcoes, X% ceu, X% natureza, X% agua, etc.
- **Analise de cores** - distribuicao de cores dominantes (verde, azul, cinzento...)
- **Paleta de cores** - top 5 cores dominantes extraidas via K-means
- **Anotacoes visuais** - setas apontando para as areas identificadas na foto
- **Filtro de selfies** - rejeita fotos com rostos grandes (foco em paisagens/cenas)
- **Historico** - dados estatisticos guardados em SQLite para insights futuros

UI com estetica retro 8-bit / pixel art.

## Stack

- **Elixir** + **Phoenix LiveView** - web framework com atualizacoes em tempo real
- **Ortex** (ONNX Runtime) - inferencia do modelo SegFormer-B0-ADE20K para segmentacao semantica
- **Evision** (OpenCV) - analise de cores, K-means clustering, detecao facial
- **Ecto + SQLite** - persistencia dos dados estatisticos
- **Tailwind CSS** - estilizacao com tema pixel art

## Pre-requisitos

- Elixir >= 1.15
- Erlang/OTP >= 25
- Rust/Cargo (necessario para compilar Ortex)

## Setup

```bash
# Instalar dependencias
mix setup

# Descarregar o modelo SegFormer ONNX (~15MB)
mix run priv/scripts/download_model.exs

# Criar base de dados
mix ecto.create
mix ecto.migrate

# Arrancar o servidor
mix phx.server
```

Abrir [http://localhost:4000](http://localhost:4000)

## Como funciona

1. O utilizador faz upload de uma foto (ou tira uma no telemovel)
2. O filtro de selfies verifica se ha rostos grandes na imagem
3. Em paralelo:
   - **SegFormer-B0-ADE20K** classifica cada pixel em 150 categorias (ceu, edificio, arvore, estrada, agua, etc.)
   - **Evision/OpenCV** analisa a distribuicao de cores via HSV e extrai cores dominantes via K-means
4. As 150 categorias sao agrupadas em grupos user-friendly (construcoes, ceu, natureza, agua, estrada, pessoas, veiculos, interior)
5. Os resultados sao apresentados com barras de progresso, paleta de cores e anotacoes visuais sobre a foto
6. Os dados estatisticos sao guardados em SQLite (a imagem nao e guardada)

## Categorias de segmentacao

| Grupo | Exemplos de classes ADE20K |
|-------|---------------------------|
| Construcoes | building, wall, house, skyscraper, tower, bridge, fence |
| Ceu | sky |
| Natureza | tree, grass, plant, flower, mountain, hill, field, rock, sand |
| Agua | water, sea, river, lake, waterfall |
| Estrada | road, sidewalk, path, stairs |
| Pessoas | person |
| Veiculos | car, bus, truck, boat, airplane, bicycle |
| Interior | floor, ceiling, bed, chair, table, sofa, etc. |

## Mobile

No telemovel, a app deteta automaticamente o dispositivo e mostra um botao para tirar foto diretamente com a camara (camara traseira). Tambem permite escolher da galeria.

## Estrutura

```
lib/
  na_foto/
    analyses/            # Schema Ecto + context para persistencia
    ml/
      model_server.ex    # GenServer que carrega o modelo ONNX
      preprocessing.ex   # Resize + normalizacao ImageNet
      ade20k_labels.ex   # 150 labels ADE20K + agrupamento
    segmentation.ex      # Segmentacao semantica + calculo de centroides
    color_analysis.ex    # Classificacao HSV + K-means
    selfie_filter.ex     # Detecao facial com Haar Cascade
    analyzer.ex          # Orquestrador
  na_foto_web/
    live/
      upload_live.ex     # LiveView principal
      history_live.ex    # Historico de analises
```
