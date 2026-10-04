# Metaverso Simulados

Plataforma para criar simulados escolares, cadastrar alunos e (em breve) corrigir cartões-resposta automaticamente.

**Stack:** Ruby on Rails 8.1 · Hotwire (Turbo + Stimulus) · Tailwind CSS · PostgreSQL 17 · Docker

## Como rodar

Só é preciso ter o Docker Desktop instalado e aberto.

```bash
docker compose up
```

Acesse http://localhost:3000. Na primeira vez, as gems são instaladas e o banco é criado automaticamente.

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
| `ExamSubject` | (no simulado) | Matéria + nº de questões + valor por questão + ordem |
| `ExamQuestion` | Gabarito | Gerada automaticamente; alternativa correta e anulação |
| `AnswerSheet` | (em breve) | Cartão-resposta de um aluno (imagem + status + nota) |
| `SheetAnswer` | (em breve) | Alternativa lida em cada questão + confiança da leitura |

### Regras de correção (`AnswerSheet#points_for`)

- Acertou: ganha o valor da questão.
- Errou, deixou em branco ou marcou mais de uma alternativa: zero.
- Questão anulada: todos ganham o ponto.

## Identidade visual

Cores tiradas do site do [Colégio Metaverso](https://colegiometaverso.com.br/), definidas como tokens do Tailwind em `app/assets/tailwind/application.css`:

| Token | Cor | Uso |
|---|---|---|
| `navy-800` | `#1C2D61` | Primária (menu, botões, títulos) |
| `green-700` | `#006C21` | Secundária (ações, sucesso) |
| `gold-400` | `#F8B81F` | Destaques |
| `green-400` | `#31B978` | Degradê verde → azul do site |

Fonte: Plus Jakarta Sans. Tem modo claro e escuro, que segue o sistema e pode ser trocado no botão de lua/sol.

## Recursos de interface

- **Ctrl+K:** busca global de alunos, turmas, simulados e matérias, mais ações rápidas.
- **Gabarito pelo teclado:** digite A–E e o cursor avança; `X` anula, `⌫` limpa, `Ctrl+S` salva.
- **Arrastar e soltar** para reordenar as matérias do simulado (SortableJS).
- **Composição da nota ao vivo** no formulário de simulado.
- Notificações (toasts), diálogo de confirmação próprio, transições entre páginas (View Transitions) e atualização por morphing (Turbo 8).

## Onde o Hotwire aparece

- **Turbo Frames:** edição de matéria na própria linha (`subjects/_subject`), filtro de alunos sem recarregar a página (`students/index`).
- **Stimulus:** `exam_form_controller.js` (adicionar e remover matérias e mostrar os totais ao vivo), `auto_submit_controller.js` (busca enquanto digita).
- **Turbo Streams:** serão usados para atualizar o status dos cartões em tempo real durante a leitura.

## Próximos passos

1. Prova de conceito da leitura óptica (Python + OpenCV) com o cartão real da escola.
2. Upload de cartões em lote, com leitura em background (Solid Queue).
3. Tela de revisão das marcações e cálculo das notas.
4. Relatórios por turma e exportação para Excel/PDF.
