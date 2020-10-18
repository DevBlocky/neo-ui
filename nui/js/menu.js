// Basic menu component
Vue.component('neo-menu', {
    template: '#menu_template',
    // allow child components to get the menu
    provide() {
        return { menu: this.menu };
    },
    props: {
        menu: { type: Object, required: true },
        buttons: { type: Array, required: true },
    },
    computed: {
        btnIndex() {
            return this.menu.index || 0;
        },
        selectedButton() {
            let index = this.btnIndex;
            return this.buttons.length > index
                ? this.buttons[index]
                : null;
        },
        descHtml() {
            if (!this.selectedButton || !this.selectedButton.desc) return;
            const template = this.selectedButton.descTemplate || '{0}';
            return safeTextWithTemplate(this.selectedButton.desc, template);
        },
    },
});
