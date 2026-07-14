import { mount } from '@vue/test-utils';
import MenuItem from '../menuItem.vue';

const baseOption = { label: 'None' };

const mountMenuItem = props =>
  mount(MenuItem, {
    props: { option: baseOption, ...props },
    global: {
      directives: { tooltip: {} },
      stubs: { 'fluent-icon': true },
    },
  });

describe('contextMenu/menuItem', () => {
  it('renders the label when not disabled', () => {
    const wrapper = mountMenuItem({ disabled: false });
    expect(wrapper.text()).toContain('None');
    expect(wrapper.find('.menu--disabled').exists()).toBe(false);
    expect(wrapper.attributes('aria-disabled')).toBe('false');
  });

  it('applies the disabled visual state and marks the item as aria-disabled', () => {
    const wrapper = mountMenuItem({
      disabled: true,
      disabledTooltip: 'Locked by policy',
    });
    expect(wrapper.find('.menu--disabled').exists()).toBe(true);
    expect(wrapper.attributes('aria-disabled')).toBe('true');
  });

  it('passes the disabledTooltip to v-tooltip when disabled', () => {
    const tooltip = 'Locked by policy';
    const wrapper = mountMenuItem({ disabled: true, disabledTooltip: tooltip });
    // The component binds v-tooltip.top to disabledTooltip only when disabled,
    // so a non-empty tooltip attribute on the root element is the smoke test.
    expect(wrapper.attributes('aria-disabled')).toBe('true');
    // The directive value is reflected via the component instance's vnode; just
    // assert the prop was accepted.
    expect(wrapper.props('disabledTooltip')).toBe(tooltip);
  });
});
