module ApplicationHelper
  AVATAR_COLORS = %w[
    bg-cocoa-100 text-cocoa-700
    bg-caramel-100 text-caramel-700
    bg-sand-200 text-sand-800
    bg-stone-200 text-stone-700
    bg-cocoa-200 text-cocoa-800
    bg-caramel-200 text-caramel-800
  ].each_slice(2).map { |classes| classes.join(" ") }.freeze

  # Cores das matérias nos gráficos/chips (sempre as mesmas para a mesma matéria),
  # alternando claro/escuro para as vizinhas se distinguirem
  SUBJECT_COLORS = %w[#43322a #c98f4d #a8a29e #84644d #dcc9a3 #985f2b #57534e #bb9864].freeze

  def nav_link(label, path, icon_name, match: path)
    active = match == root_path ? current_page?(root_path) : request.path.start_with?(match)
    link_to path, class: "nav-item", aria: { current: ("page" if active) } do
      safe_join([ icon(icon_name), tag.span(label) ])
    end
  end

  def points(value)
    number_with_precision(value, precision: 2, strip_insignificant_zeros: true, separator: ",", delimiter: ".")
  end

  def initials(name)
    parts = name.to_s.split
    [ parts.first, (parts.last if parts.size > 1) ].compact.map { |p| p[0] }.join.upcase
  end

  def avatar(name, size: "size-9 text-xs")
    color = AVATAR_COLORS[name.to_s.sum % AVATAR_COLORS.size]
    tag.span(initials(name), class: "inline-flex #{size} shrink-0 items-center justify-center rounded-full font-bold #{color}")
  end

  # Nome da matéria para exibir. A de língua estrangeira tem dois gabaritos, então o
  # nome cadastrado (ex.: "Espanhol") não diz a verdade para quem fez Inglês: no cartão
  # de um aluno mostra a língua que ele escolheu; nas telas do simulado, as duas.
  def subject_label(exam_subject, language = :exam)
    return exam_subject.subject.name unless exam_subject.foreign_language?
    return "Inglês / Espanhol" if language == :exam

    Exam::LANGUAGES.fetch(language.to_s, "Língua estrangeira")
  end

  # Dentro de um simulado (ExamSubject) a cor segue a ordem da matéria, então as
  # matérias de um mesmo simulado nunca repetem cor (até 8). Fora dele (Subject), o id.
  def subject_color(item)
    index = if item.is_a?(ExamSubject)
      @exam_subject_order ||= {}
      order = (@exam_subject_order[item.exam_id] ||= item.exam.exam_subjects.map(&:id))
      order.index(item.id) || item.subject_id
    else
      item.id
    end
    SUBJECT_COLORS[index % SUBJECT_COLORS.size]
  end

  def page_header(title, subtitle: nil, eyebrow: nil, &block)
    render layout: "shared/page_header", locals: { title: title, subtitle: subtitle, eyebrow: eyebrow }, &(block || proc { })
  end

  def empty_state(icon_name, title, description = nil, &block)
    render layout: "shared/empty_state", locals: { icon_name: icon_name, title: title, description: description }, &(block || proc { })
  end
end
