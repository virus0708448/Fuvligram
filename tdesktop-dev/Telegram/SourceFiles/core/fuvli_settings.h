#pragma once

#include <QtCore/QFile>
#include <QtCore/QJsonDocument>
#include <QtCore/QJsonObject>
#include <rpl/variable.h>

namespace Core {

class FuvliSettings final {
public:
	static FuvliSettings &Instance() {
		static FuvliSettings instance;
		return instance;
	}

	// 1. Privacy
	rpl::variable<bool> ghostRead = false;
	rpl::variable<bool> hideTyping = false;
	rpl::variable<bool> ghostStories = false;
	rpl::variable<bool> antiDelete = false;

	// 2. Interface
	rpl::variable<bool> hideStoriesBar = false;
	rpl::variable<bool> hideSponsored = false;
	rpl::variable<bool> compactDialogs = false;
	rpl::variable<bool> exactTimeSeconds = false;

	// 3. Tools
	rpl::variable<bool> showPeerId = true;
	rpl::variable<bool> confirmCalls = true;

	void load(const QString &path) {
		_path = path;
		QFile file(_path);
		if (!file.open(QIODevice::ReadOnly)) {
			return;
		}
		const auto obj = QJsonDocument::fromJson(file.readAll()).object();
		ghostRead = obj.value("ghostRead").toBool(false);
		hideTyping = obj.value("hideTyping").toBool(false);
		ghostStories = obj.value("ghostStories").toBool(false);
		antiDelete = obj.value("antiDelete").toBool(false);
		hideStoriesBar = obj.value("hideStoriesBar").toBool(false);
		hideSponsored = obj.value("hideSponsored").toBool(false);
		compactDialogs = obj.value("compactDialogs").toBool(false);
		exactTimeSeconds = obj.value("exactTimeSeconds").toBool(false);
		showPeerId = obj.value("showPeerId").toBool(true);
		confirmCalls = obj.value("confirmCalls").toBool(true);
	}

	void save() const {
		if (_path.isEmpty()) {
			return;
		}
		QJsonObject obj;
		obj["ghostRead"] = ghostRead.current();
		obj["hideTyping"] = hideTyping.current();
		obj["ghostStories"] = ghostStories.current();
		obj["antiDelete"] = antiDelete.current();
		obj["hideStoriesBar"] = hideStoriesBar.current();
		obj["hideSponsored"] = hideSponsored.current();
		obj["compactDialogs"] = compactDialogs.current();
		obj["exactTimeSeconds"] = exactTimeSeconds.current();
		obj["showPeerId"] = showPeerId.current();
		obj["confirmCalls"] = confirmCalls.current();

		QFile file(_path);
		if (file.open(QIODevice::WriteOnly)) {
			file.write(QJsonDocument(obj).toJson(QJsonDocument::Indented));
		}
	}

	void resetToDefaults() {
		ghostRead = false;
		hideTyping = false;
		ghostStories = false;
		antiDelete = false;
		hideStoriesBar = false;
		hideSponsored = false;
		compactDialogs = false;
		exactTimeSeconds = false;
		showPeerId = true;
		confirmCalls = true;
		save();
	}

private:
	FuvliSettings() = default;
	QString _path;
};

} // namespace Core