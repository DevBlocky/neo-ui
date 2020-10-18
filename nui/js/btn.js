// Button component, rendered by the btn-group component
Vue.component('neo-btn', {
    template: '#btn_template',
    mixins: [winMsgMixin],
    inject: ['menu'],
    props: {
        button: { type: Object, required: true },
        selected: Boolean,
    },
    methods: {
        handleAction({ action }) {
            if (!this.selected) return;
            if (action === 'sel') {
                // if it's a checkbox, update the value and send another event
                if (this.isCheckbox) {
                    this.button.check = !this.button.check;
                }

                // sends the select event
                // must use $nextTick so that check ev propagates first
                this.$nextTick(() =>
                    postClient({
                        type: 'select',
                        button: this.button.id,
                        menu: this.menu.id,
                    }),
                );

                // we don't need to go any further
                return;
            }

            if (!this.button.list) return;
            else if (action === 'right') this.listIndex = this.addToIndex(1);
            else if (action === 'left') this.listIndex = this.addToIndex(-1);
        },
        addToIndex(val) {
            const { length } = this.button.list;
            let index = this.listIndex;
            index += val;

            // this will wrap the menu past index bounds
            if (index >= length) index = 0;
            else if (index < 0) index = length - 1;

            return index;
        },
    },
    computed: {
        listIndex: {
            get() {
                return this.button.listIndex || 0;
            },
            set(v) {
                this.$set(this.button, 'listIndex', v);
            },
        },
        listVal() {
            const { list } = this.button;
            if (!list) return null;

            // this shouldn't fail because of the watch
            return list[this.listIndex];
        },
        isCheckbox() {
            return (
                this.button.check !== null && this.button.check !== undefined
            );
        },
        checked() {
            return this.button.check === true;
        },
        textHtml() {
            const { text, textTemplate } = this.button;
            if (!text) return;
            const template = textTemplate || '{0}';
            return safeTextWithTemplate(text, template);
        },
    },
    watch: {
        listIndex(index) {
            const { length } = this.button.list;

            // send a client ev
            postClient({
                type: 'list_move',
                button: this.button.id,
                menu: this.menu.id,
                index: this.listIndex,
            });
        },
        checked(checked) {
            postClient({
                type: 'check_update',
                button: this.button.id,
                menu: this.menu.id,
                checked,
            });
        },
    },
});
