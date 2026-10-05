# Leitor de cartão-resposta (OMR)

Prova de conceito em Python + OpenCV. Lê a foto (celular) ou o scan de um cartão-resposta e devolve as marcações em JSON.

## Como funciona

**Padrão: leitura automática da grade** (`omr/grid.py`). A escola muda o cartão a cada simulado (40 questões A–E, 25 questões A–D...), então o leitor não depende de um modelo fixo:

1. Endireita a folha (borda do papel ou moldura). Testa várias formas e fica com a que gera uma grade válida.
2. Acha as bolinhas, monta colunas de alternativas (espaçamento constante) e linhas (retas, tolerando rotação). As bolinhas marcadas, que nem sempre aparecem como círculo, são deduzidas pela grade.
3. Numera bloco por bloco e **confere com o nº de questões do simulado**. Se não bater, recusa com o motivo, em vez de chutar.
4. Mede o preenchimento comparando com as outras bolinhas da própria foto: referência por letra ("B" e "D" impressos têm mais tinta), ajuste por linha (sombra) e limite proporcional ao tom da caneta naquela foto.
5. Língua (Inglês/Espanhol): procura o par de bolinhas na linha acima da grade (mesma altura, ~8–20% da largura entre elas). A rabiscada também é aceita como mancha escura. As duas são comparadas entre si; se forem parecidas, a língua fica em branco e o cartão vai para revisão.

Validação: 3 fotos reais "Meta Teste 1" (25 questões A–D), 25/25 e língua certa em todas. Cartões sintéticos de 40 questões A–E: 60/60 lidos, 100% de acerto. Sem nenhuma resposta errada sem pedir revisão.

**Reserva: modelo fixo em PDF.** Só é usado se a leitura automática falhar e o simulado tiver exatamente o formato do modelo:

1. **Modelo** (`omr/template.py`): renderiza o PDF do cartão em branco e acha as 200 bolinhas (40 questões × A–E) e as de Inglês/Espanhol.
2. **Alinhamento** (`omr/align.py`): o cartão não tem marcadores de canto, então a foto é alinhada ao modelo pelo próprio desenho (logo, textos, números), com ORB + RANSAC, e depois refinada com ECC. Isso corrige perspectiva, rotação e escala.
3. **Leitura** (`omr/reader.py`): mede quanto cada bolinha está mais escura que no modelo em branco, calibrando pela mediana da própria foto (desfoque, luz, papel). Cada questão sai como:
   - `ok`: uma alternativa marcada;
   - `blank`: em branco;
   - `multiple`: duas ou mais (vale zero);
   - `doubtful`: marca fraca, rasura ou X → vai para revisão humana.

## Serviço HTTP (usado pelo Rails)

No `compose.yml` o container `omr` roda `uvicorn omr.server:app` na porta 8000:

- `GET /health`: modelos disponíveis.
- `POST /read` (multipart `image`, `questions`, `options` e, opcional, `template`): marcações em JSON + `overlay_jpeg_base64` (imagem de conferência). Responde 422 com `{ error }` quando a foto não pode ser lida.

## Uso pela linha de comando

```bash
docker build -t metaverso-omr omr
docker run --rm -v "$PWD/omr:/omr" metaverso-omr python -m omr templates/meta_simulado_enem_40q.pdf foto.jpg conferencia.jpg
```

## Fotos reais

Coloque fotos em `out/real/` (fora do Git: são dados de alunos) e confira contra o gabarito anotado à mão:

```bash
docker compose exec omr python -m tools.check_real out/real/foto.jpg "CDBCCDCBAABBDAABBCBABBCBC" A-D espanhol
docker compose exec omr python -m tools.stress_real out/real/foto.jpg "CDBCCDCBAABBDAABBCBABBCBC" 4 espanhol 20
```

## Testes com cartões sintéticos

Enquanto não há cartões reais preenchidos, `tools/synth.py` gera fotos simuladas, e `tools/evaluate.py` compara a leitura com a resposta real de cada uma.

```bash
docker run --rm -v "$PWD/omr:/omr" metaverso-omr python -m tools.synth templates/meta_simulado_enem_40q.pdf out/synth 30
docker run --rm -v "$PWD/omr:/omr" metaverso-omr python -m tools.evaluate templates/meta_simulado_enem_40q.pdf out/synth
```

Resultado atual (60 cartões, 2.400 questões, incluindo fotos com distorção forte): **100% de acerto, 0 respostas erradas sem revisão**, ~2 questões por cartão enviadas para revisão, ~1 s por cartão.

> Cartões sintéticos não substituem fotos reais. O próximo passo é validar com cartões preenchidos de verdade.
