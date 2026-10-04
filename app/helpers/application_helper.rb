module ApplicationHelper
  AVATAR_COLORS = %w[
    bg-navy-100 text-navy-700 dark:bg-navy-400/15 dark:text-navy-200
    bg-green-100 text-green-700 dark:bg-green-400/15 dark:text-green-300
    bg-gold-100 text-gold-700 dark:bg-gold-400/15 dark:text-gold-300
    bg-sky-100 text-sky-700 dark:bg-sky-400/15 dark:text-sky-300
    bg-violet-100 text-violet-700 dark:bg-violet-400/15 dark:text-violet-300
    bg-rose-100 text-rose-700 dark:bg-rose-400/15 dark:text-rose-300
  ].each_slice(4).map { |classes| classes.join(" ") }.freeze

  # Cores das matérias nos gráficos/chips: sempre as mesmas para a mesma matéria
  SUBJECT_COLORS = %w[#1c2d61 #10a04a #f8b81f #41589d #31b978 #e59e07 #8ba0d3 #05561d].freeze

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

  def subject_color(subject)
    SUBJECT_COLORS[subject.id % SUBJECT_COLORS.size]
  end

  def page_header(title, subtitle: nil, eyebrow: nil, &block)
    render layout: "shared/page_header", locals: { title: title, subtitle: subtitle, eyebrow: eyebrow }, &(block || proc { })
  end

  def empty_state(icon_name, title, description = nil, &block)
    render layout: "shared/empty_state", locals: { icon_name: icon_name, title: title, description: description }, &(block || proc { })
  end
end
