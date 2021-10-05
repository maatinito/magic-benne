# frozen_string_literal: true

module ApplicationHelper

  def flash_class(level, sticky: false, fixed: false)
    class_names = case level
    when 'notice'
      ['alert-success']
    when 'alert'
      ['alert-danger']
    end
    if sticky
      class_names << 'sticky'
    end
    if fixed
      class_names << 'alert-fixed'
    end
    class_names.join(' ')
  end

  def render_to_element(selector, partial:, outer: false, locals: {})
    method = outer ? 'outerHTML' : 'innerHTML'
    html = escape_javascript(render partial: partial, locals: locals)
    # rubocop:disable Rails/OutputSafety
    raw("document.querySelector('#{selector}').#{method} = \"#{html}\";")
    # rubocop:enable Rails/OutputSafety
  end

  def append_to_element(selector, partial:, locals: {})
    html = escape_javascript(render partial: partial, locals: locals)
    # rubocop:disable Rails/OutputSafety
    raw("document.querySelector('#{selector}').insertAdjacentHTML('beforeend', \"#{html}\");")
    # rubocop:enable Rails/OutputSafety
  end

  def render_flash(timeout: false, sticky: false, fixed: false)
    if flash.any?
      html = render_to_element('#flash_messages', partial: 'layouts/flash_messages', locals: { sticky: sticky, fixed: fixed }, outer: true)
      flash.clear
      if timeout
        html += remove_element('#flash_messages', timeout: timeout, inner: true)
      end
      html
    end
  end

end
