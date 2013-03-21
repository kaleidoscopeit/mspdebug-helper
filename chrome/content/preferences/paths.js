Components.utils.import("resource://gre/modules/XPCOMUtils.jsm");
XPCOMUtils.defineLazyModuleGetter(this, "DownloadsCommon",
	"resource:///modules/DownloadsCommon.jsm");

var panePaths = {
  _pane: null,

  /**
   * Initialization of this.
   */
  init: function ()
  {
    this._pane = document.getElementById("panePaths");

		this._prefService =
			Components.classes["@mozilla.org/preferences-service;1"]
				.getService(Components.interfaces.nsIPrefBranch);	
  },

  /**
   * Displays a file picker in which the user can choose the location where
   * a file is placed.
   */
  chooseFilePath: function (elem) {
    const nsIFilePicker = Components.interfaces.nsIFilePicker;
    const nsILocalFile = Components.interfaces.nsILocalFile;

    var fp = Components.classes["@mozilla.org/filepicker;1"]
                       .createInstance(nsIFilePicker);

    var bundlePreferences = document.getElementById("bundlePreferences");
    var title = bundlePreferences.getString("pathsChooseFileTitle");

    fp.appendFilters(nsIFilePicker.filterApps);
    fp.init(window, title, nsIFilePicker.modeOpen);

		var preferenceName = elem.getAttribute("preference");
		var preferenceValue = this._prefService.getCharPref(preferenceName);

    var preferenceObj = document.getElementById(preferenceName);
    var preferenceValue = preferenceObj.value;

    if (preferenceValue && preferenceValue.exists()) {
      fp.displayDirectory = preferenceValue.parent;
    } 

    if (fp.show() == nsIFilePicker.returnOK) {
      var file = fp.file.QueryInterface(nsILocalFile);
			elem.value = fp.file.path;
    };
  },

  /**
   * Displays a file picker in which the user can choose the location where
   * a directory is placed.
   */
  chooseDirectoryPath: function (elem) {
    const nsIFilePicker = Components.interfaces.nsIFilePicker;
    const nsILocalFile = Components.interfaces.nsILocalFile;

    var fp = Components.classes["@mozilla.org/filepicker;1"]
                       .createInstance(nsIFilePicker);

    var bundlePreferences = document.getElementById("bundlePreferences");
    var title = bundlePreferences.getString("pathsChooseFileTitle");

    fp.appendFilters(nsIFilePicker.filterApps);
    fp.init(window, title, nsIFilePicker.modeGetFolder);

		var preferenceName = elem.getAttribute("preference");
		var preferenceValue = this._prefService.getCharPref(preferenceName);

    var preferenceObj = document.getElementById(preferenceName);
    var preferenceValue = preferenceObj.value;

    if (preferenceValue && preferenceValue.exists()) {
      fp.displayDirectory = preferenceValue.parent;
    } 

    if (fp.show() == nsIFilePicker.returnOK) {
      var file = fp.file.QueryInterface(nsILocalFile);
			elem.value = fp.file.path;
    }
  },

  displayPath: function(elem) {

		var preferenceName = elem.getAttribute("preference");
		var preference = document.getElementById(preferenceName);

		if (preference.value === null) return "";
		else return preference.value.path;
  }
};

