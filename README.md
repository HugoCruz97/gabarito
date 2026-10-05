# Metaverso Simulados

Plataforma para criar simulados escolares, cadastrar alunos e corrigir cartões-resposta automaticamente por foto.

**Stack:** Ruby on Rails 8.1 · Hotwire (Turbo + Stimulus) · Tailwind CSS · PostgreSQL 17 · Docker

## Como rodar

Só é preciso ter o Docker Desktop instalado e aberto.

```bash
docker compose up
```

Acesse http://localhost:3000. Na primeira vez, as gems são instaladas e o banco é criado automaticamente.

Sobem três containers: `web` (Rails), `db` (PostgreSQL) e `omr` (leitor de cartões em Python, porta 8000).

> Mudou `compose.yml` ou algo em `config/initializers`? Rode `docker compose up -d` (recria os containers). Um `restart` não aplica variáveis novas.

### Hot reload

Com o [Hotwire Spark](https://github.com/hotwired/spark), salvar um arquivo atualiza o navegador sozinho em cerca de 1 segundo, sem perder o estado da página:

- **Views (HTML):** a página é atualizada por morphing, sem recarregar.
- **CSS / classes do Tailwind:** o estilo é recarregado na hora.
- **Controllers Stimulus:** o JavaScript é recarregado.
- **Ruby (models, controllers):** o Rails recarrega no próximo request.

No Docker com Windows, o container não recebe os avisos de arquivo alterado. Por isso o `compose.yml` define `LISTEN_FORCE_POLLING=1` (veja `config/initializers/listen_polling.rb`) e o Tailwind roda com `watch[poll]`.

### Comandos úteis

```bash
docker compose exec web bin/rails db:seed      # dados de exemplo
docker compose exec web bin/rails test         # testes
docker compose exec web bin/rails console      # console Rails
docker compose exec web bin/rails db:migrate   # aplicar migrations
docker compose down                            # parar tudo
```

## Estrutura

| Model | Tela | Descrição |
|---|---|---|
| `Classroom` | Turmas | Turmas e ano letivo |
| `Student` | Alunos | Nome, matrícula (opcional), turma |
| `Subject` | Matérias | Catálogo de matérias reutilizável |
| `Exam` | Simulados | Título, data, turmas, alternativas (A–D ou A–E) |
| `ExamSubject` | (no simulado) | Matéria + nº de questões + ordem. Vale 10 pontos; cada questão vale 10 ÷ nº de questões |
| `ExamQuestion` | Gabarito | Gerada automaticamente; alternativa correta e anulação |
| `AnswerSheet` | Cartões e notas | Cartão de um aluno: foto, imagem de conferência, língua, status (fila → lendo → corrigido/revisar → conferido) e nota |
| `SheetAnswer` | Revisão | Alternativa lida em cada questão, confiança e classificação (ok, em branco, múltipla, duvidosa, ajustada) |

### Regras de correção (`AnswerSheet#points_for`)

- Acertou: ganha o valor da questão.
- Errou, deixou em branco ou marcou mais de uma alternativa: zero.
- Questão anulada: todos ganham o ponto.

## Identidade visual

Paleta de cinza, bege e marrom, definida como tokens do Tailwind em `app/assets/tailwind/application.css`:

| Token | Cor | Uso |
|---|---|---|
| `cocoa-900` / `cocoa-800` | `#2F241E` / `#43322A` | Primária (menu, botões, títulos) |
| `caramel-500` | `#B57636` | Destaques e ações |
| `sand-400` / `sand-50` | `#CCB07F` / `#FBF9F4` | Detalhes, avisos e fundo creme |
| `stone-*` | cinza quente (padrão do Tailwind) | Textos e neutros |

Marca: uma bolinha de cartão-resposta preenchida com ✓ entre duas vazias (`brand_mark` em `app/helpers/icons_helper.rb`, `public/icon.svg`). Fonte: Plus Jakarta Sans. Só tem tema claro.

## Recursos de interface

- **Ctrl+K:** busca global de alunos, turmas, simulados e matérias, mais ações rápidas.
- **Gabarito pelo teclado:** digite A–E e o cursor avança; `X` anula, `⌫` limpa, `Ctrl+S` salva.
- **Arrastar e soltar** para reordenar as matérias do simulado (SortableJS).
- **Composição da nota ao vivo** no formulário de simulado.
- Notificações (toasts), diálogo de confirmação próprio, transições entre páginas (View Transitions) e atualização por morphing (Turbo 8).

## Onde o Hotwire aparece

- **Turbo Frames:** edição de matéria na própria linha (`subjects/_subject`), filtro de alunos sem recarregar a página (`students/index`).
- **Stimulus:** `exam_form_controller.js` (adicionar e remover matérias e mostrar os totais ao vivo), `auto_submit_controller.js` (busca enquanto digita).
- **Turbo Streams:** `AnswerSheet` usa `broadcasts_refreshes_to :exam`; a página do simulado (`turbo_stream_from @exam`) se atualiza sozinha enquanto os cartões são lidos.

## Correção por foto

1. Na página do simulado, **Enviar cartões**: escolha várias fotos e o aluno de cada uma.
2. Cada foto vira um `AnswerSheet` e o `ReadAnswerSheetJob` envia ao serviço `omr` (`OmrClient`, HTTP).
3. O leitor devolve as marcações e a imagem de conferência; o Rails grava as respostas e calcula a nota.
4. A lista de cartões se atualiza sozinha (Turbo Streams). Cartões com dúvida aparecem como **Revisar**.
5. Na revisão, a professora confere a imagem, ajusta marcações, aluno ou língua e confirma. O sistema já abre o próximo cartão a revisar.
6. Mudou o gabarito ou o simulado? As notas já lançadas são recalculadas.

O leitor descobre a grade do cartão na própria foto, usando o nº de questões e de alternativas do simulado. Serve para qualquer variação do cartão da escola, sem cadastrar modelo. Um modelo em PDF (`omr/templates/`, fora do Git) fica só como reserva.

## Prova adaptada

O aluno marcado como **"Faz prova adaptada"** é corrigido pelo **gabarito adaptado** do simulado, quando o simulado tem a opção **"Tem prova adaptada"** ligada. A prova adaptada usa as mesmas questões e o mesmo cartão; só o gabarito muda, inclusive Inglês/Espanhol e anulações, todos independentes. Os gabaritos ficam em `ExamQuestion::KEY_FIELDS`. Mudar a marcação do aluno ou o gabarito recalcula as notas já lançadas.

## Importação de alunos

Alunos → **Importar planilha** (.xlsx). Colunas reconhecidas pelo título: Nome (obrigatória), Matrícula, Turma e Adaptada. Antes de gravar aparece uma prévia (novo, atualizar, sem mudança, erro). Turmas novas são criadas na hora, e alunos já cadastrados são reconhecidos pela matrícula, ou pelo nome dentro da turma. Há uma planilha modelo para baixar. Código: `StudentImport` e `StudentImportsController`.

## Relatório de notas

Simulado → **Relatório de notas**: ranking (empates dividem a posição), nota por matéria, média, maior e menor nota, média por matéria, filtro por turma, pendências e alunos sem cartão. Exporta para Excel (`.xlsx`); para PDF, use **Imprimir / PDF** (layout de impressão sem menu). Código: `ExamReport` e `ReportsController`.

## Próximos passos

1. Envio de PDF escaneado com vários cartões de uma vez.
2. Boletim individual do aluno, análise das questões e evolução entre simulados.
