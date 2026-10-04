module ApplicationHelper
  INPUT_CLASS = "block w-full rounded-md border border-gray-300 px-3 py-2 shadow-sm focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500".freeze
  LABEL_CLASS = "block text-sm font-medium text-gray-700 mb-1".freeze
  BUTTON_CLASS = "inline-flex items-center rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-indigo-500 cursor-pointer".freeze
  SECONDARY_BUTTON_CLASS = "inline-flex items-center rounded-md border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 shadow-sm hover:bg-gray-50 cursor-pointer".freeze
  DANGER_BUTTON_CLASS = "inline-flex items-center rounded-md border border-red-200 bg-white px-4 py-2 text-sm font-medium text-red-600 hover:bg-red-50 cursor-pointer".freeze

  def nav_link(label, path)
    active = current_page?(path) || request.path.start_with?(path)
    classes = active ? "bg-indigo-700 text-white" : "text-indigo-100 hover:bg-indigo-500"
    link_to label, path, class: "rounded-md px-3 py-2 text-sm font-medium #{classes}"
  end

  def points(value)
    number_with_precision(value, precision: 2, strip_insignificant_zeros: true, separator: ",", delimiter: ".")
  end
end
