var $ = require('jquery');
var DropdownView = require('../../../../javascripts/dashboard/common/dropdown-view');

var ESCAPE_KEY_CODE = 27;

var simulateEscapeKeyPress = function () {
  var e = $.Event('keydown');
  e.keyCode = e.which = ESCAPE_KEY_CODE;
  $(document).trigger(e);
};

describe('dashboard/common/dropdown-view', function () {
  beforeEach(function () {
    this.node = $('<a></a>');
    this.view = new DropdownView({
      target: this.node
    });

    this.view.render();
    document.body.appendChild(this.view.el);
  });

  afterEach(function () {
    var el = this.view.el;
    var parent = el.parentNode;
    parent && parent.removeChild(el);
    this.view.remove();
  });

  it('should be closed initially', function () {
    expect(this.view.model.get('open')).toBe(false);
  });

  it('should open when target is clicked', function () {
    this.node.trigger('click');
    expect(this.view.model.get('open')).toBe(true);
  });

  it('should close on ESC key event', function () {
    spyOn(this.view, 'hide');
    simulateEscapeKeyPress();

    expect(this.view.hide).toHaveBeenCalled();
    expect(this.view.model.get('open')).toBe(false);
  });

  it('should not have any leaks', function () {
    expect(this.view).toHaveNoLeaks();
  });
});