# frozen_string_literal: true

module ApplicationHelper
  def flash_class(level, sticky: false, fixed: false)
    class_names = case level
                  when 'notice'
                    ['alert-success']
                  when 'alert'
                    ['alert-danger']
                  end
    class_names << 'sticky' if sticky
    class_names << 'alert-fixed' if fixed
    class_names.join(' ')
  end

  def remove_element(selector, timeout: 0, inner: false)
    script = +'(function() {'
    script << "var el = document.querySelector('#{selector}');"
    method = (inner ? "el.innerHTML = ''" : 'el.parentNode.removeChild(el)')
    script << if timeout&.positive?
                "if (el) { setTimeout(function() { #{method}; }, #{timeout}); }"
              else
                "if (el) { #{method} };"
              end
    script << '})();'
    raw(script)
  end

  def render_to_element(selector, partial:, outer: false, locals: {})
    method = outer ? 'outerHTML' : 'innerHTML'
    html = escape_javascript(render(partial: partial, locals: locals))
    raw("document.querySelector('#{selector}').#{method} = \"#{html}\";")
  end

  def append_to_element(selector, partial:, locals: {})
    html = escape_javascript(render(partial: partial, locals: locals))
    raw("document.querySelector('#{selector}').insertAdjacentHTML('beforeend', \"#{html}\");")
  end

  def render_flash(timeout: false, sticky: false, fixed: false)
    return unless flash.any?

    html = render_to_element('#flash_messages', partial: 'layouts/flash_messages', locals: { sticky: sticky, fixed: fixed }, outer: true)
    flash.clear
    html += remove_element('#flash_messages', timeout: timeout, inner: true) if timeout
    html
  end
end
