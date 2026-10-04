# Leitor de cartão-resposta (OMR)

Prova de conceito em Python + OpenCV. Lê a foto (celular) ou o scan de um cartão-resposta e devolve as marcações em JSON.

## Como funciona

1. **Modelo** (`omr/template.py`): renderiza o PDF do cartão em branco e acha as 200 bolinhas (40 questões × A–E) e as de Inglês/Espanhol.
2. **Alinhamento** (`omr/align.py`): o cartão não tem marcadores de canto, então a foto é alinhada ao modelo pelo próprio desenho (logo, textos, números), com ORB + RANSAC, e depois refinada com ECC. Isso corrige perspectiva, rotação e escala.
3. **Leitura** (`omr/reader.py`): mede quanto cada bolinha está mais escura que no modelo em branco, calibrando pela mediana da própria foto (desfoque, luz, papel). Cada questão sai como:
   - `ok`: uma alternativa marcada;
   - `blank`: em branco;
   - `multiple`: duas ou mais (vale zero);
   - `doubtful`: marca fraca, rasura ou X → vai para revisão humana.

## Uso

```bash
docker build -t metaverso-omr omr
docker run --rm -v "$PWD/omr:/omr" metaverso-omr python -m omr templates/meta_simulado_enem_40q.pdf foto.jpg conferencia.jpg
```

## Testes com cartões sintéticos

Enquanto não há cartões reais preenchidos, `tools/synth.py` gera fotos simuladas, e `tools/evaluate.py` compara a leitura com a resposta real de cada uma.

```bash
docker run --rm -v "$PWD/omr:/omr" metaverso-omr python -m tools.synth templates/meta_simulado_enem_40q.pdf out/synth 30
docker run --rm -v "$PWD/omr:/omr" metaverso-omr python -m tools.evaluate templates/meta_simulado_enem_40q.pdf out/synth
```

Resultado atual (60 cartões, 2.400 questões, incluindo fotos com distorção forte): **100% de acerto, 0 respostas erradas sem revisão**, ~2 questões por cartão enviadas para revisão, ~1 s por cartão.

> Cartões sintéticos não substituem fotos reais. O próximo passo é validar com cartões preenchidos de verdade.
