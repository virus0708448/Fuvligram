$ErrorActionPreference = "Stop"
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$root = (Get-Location).Path

function Write-Utf8($relPath, $text) {
	$full = Join-Path $root $relPath
	$dir = Split-Path $full -Parent
	if (-not (Test-Path $dir)) {
		New-Item -ItemType Directory -Force -Path $dir | Out-Null
	}
	[System.IO.File]::WriteAllText($full, $text, $utf8NoBom)
}

function Patch-File($relPath, [scriptblock]$transform) {
	$full = Join-Path $root $relPath
	if (-not (Test-Path $full)) {
		Write-Warning "File not found: $relPath"
		return
	}
	$content = [System.IO.File]::ReadAllText($full, [System.Text.Encoding]::UTF8)
	$updated = & $transform $content
	if ($updated -ne $content) {
		[System.IO.File]::WriteAllText($full, $updated, $utf8NoBom)
		Write-Host "Patched: $relPath" -ForegroundColor Cyan
	}
}

# 1. Core settings storage (core/fuvli_settings.h)
$fuvliSettingsH = @'
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
'@

# 2. Settings UI Header (settings/settings_fuvli.h)
$settingsFuvliH = @'
#pragma once

#include "settings/settings_common_session.h"

namespace Settings {

class Fuvli : public Section<Fuvli> {
public:
	Fuvli(
		QWidget *parent,
		not_null<Window::SessionController*> controller);

	[[nodiscard]] rpl::producer<QString> title() override;

private:
	void setupContent(not_null<Window::SessionController*> controller);
};

} // namespace Settings
'@

# 3. Settings UI Implementation (settings/settings_fuvli.cpp)
$settingsFuvliCpp = @'
#include "settings/settings_fuvli.h"

#include "core/fuvli_settings.h"
#include "settings/settings_common.h"
#include "ui/painter.h"
#include "ui/vertical_list.h"
#include "ui/widgets/buttons.h"
#include "ui/widgets/labels.h"
#include "ui/wrap/vertical_layout.h"
#include "window/window_session_controller.h"
#include "styles/style_settings.h"

#include <QtGui/QLinearGradient>
#include <QtGui/QPainterPath>

namespace Settings {
namespace {

class FuvliHeaderBanner final : public Ui::RpWidget {
public:
	explicit FuvliHeaderBanner(QWidget *parent) : Ui::RpWidget(parent) {
		resize(width(), 96);
	}

protected:
	void paintEvent(QPaintEvent *) override {
		Painter p(this);
		PainterHighQualityEnabler hq(p);

		const auto margin = st::settingsButton.padding.left();
		const auto cardRect = rect().marginsRemoved(
			QMargins(margin, 8, margin, 8));

		QPainterPath path;
		path.addRoundedRect(cardRect, 14, 14);

		QLinearGradient grad(cardRect.topLeft(), cardRect.bottomRight());
		grad.setColorAt(0.0, QColor(124, 58, 237, 230));
		grad.setColorAt(1.0, QColor(79, 70, 229, 230));
		p.fillPath(path, grad);

		p.setPen(Qt::white);
		p.setFont(st::settingsSubsectionTitle.style.font);
		p.drawText(
			cardRect.adjusted(18, 14, -18, -14),
			Qt::AlignLeft | Qt::AlignTop,
			u"\u0424\u0423\u0412\u041B\u0418 \u041C\u041E\u0414  \u2022  v1.0"_q);

		p.setPen(QColor(255, 255, 255, 200));
		p.setFont(st::normalFont);
		p.drawText(
			cardRect.adjusted(18, 42, -18, -12),
			Qt::AlignLeft | Qt::AlignTop | Qt::TextWordWrap,
			u"\u0420\u0430\u0441\u0448\u0438\u0440\u0435\u043D\u043D\u044B\u0435 \u043D\u0430\u0441\u0442\u0440\u043E\u0439\u043A\u0438 \u043F\u0440\u0438\u0432\u0430\u0442\u043D\u043E\u0441\u0442\u0438, \u0438\u043D\u0442\u0435\u0440\u0444\u0435\u0439\u0441\u0430 \u0438 \u0438\u043D\u0441\u0442\u0440\u0443\u043C\u0435\u043D\u0442\u043E\u0432 Telegram"_q);
	}
};

void AddToggle(
		not_null<Ui::VerticalLayout*> container,
		const QString &label,
		rpl::variable<bool> &setting) {
	const auto button = container->add(
		object_ptr<Ui::SettingsButton>(
			container,
			rpl::single(label),
			st::settingsButtonNoIcon));
	button->toggleOn(setting.value());
	button->toggledChanges(
	) | rpl::on_next([&](bool value) {
		setting = value;
		Core::FuvliSettings::Instance().save();
	}, button->lifetime());
}

} // namespace

Fuvli::Fuvli(
	QWidget *parent,
	not_null<Window::SessionController*> controller)
: Section(parent, controller) {
	setupContent(controller);
}

rpl::producer<QString> Fuvli::title() {
	return rpl::single(u"\u0424\u0423\u0412\u041B\u0418 \u041C\u041E\u0414"_q);
}

void Fuvli::setupContent(not_null<Window::SessionController*> controller) {
	const auto content = Ui::CreateChild<Ui::VerticalLayout>(this);
	auto &s = Core::FuvliSettings::Instance();

	content->add(object_ptr<FuvliHeaderBanner>(content));
	Ui::AddSkip(content);

	Ui::AddSubsectionTitle(
		content,
		rpl::single(u"\u041F\u0440\u0438\u0432\u0430\u0442\u043D\u043E\u0441\u0442\u044C \u0438 \u0440\u0435\u0436\u0438\u043C \u043F\u0440\u0438\u0437\u0440\u0430\u043A\u0430"_q));
	AddToggle(content, u"\u041D\u0435 \u0447\u0438\u0442\u0430\u0442\u044C \u0441\u043E\u043E\u0431\u0449\u0435\u043D\u0438\u044F (Ghost Mode)"_q, s.ghostRead);
	AddToggle(content, u"\u0421\u043A\u0440\u044B\u0432\u0430\u0442\u044C \u0441\u0442\u0430\u0442\u0443\u0441 \u00AB\u043F\u0435\u0447\u0430\u0442\u0430\u0435\u0442...\u00BB"_q, s.hideTyping);
	AddToggle(content, u"\u0410\u043D\u043E\u043D\u0438\u043C\u043D\u044B\u0439 \u043F\u0440\u043E\u0441\u043C\u043E\u0442\u0440 \u0438\u0441\u0442\u043E\u0440\u0438\u0439"_q, s.ghostStories);
	AddToggle(content, u"\u0410\u043D\u0442\u0438-\u0443\u0434\u0430\u043B\u0435\u043D\u0438\u0435 \u0441\u043E\u043E\u0431\u0449\u0435\u043D\u0438\u0439"_q, s.antiDelete);
	Ui::AddSkip(content);
	Ui::AddDividerText(
		content,
		rpl::single(u"\u0420\u0435\u0436\u0438\u043C \u043F\u0440\u0438\u0437\u0440\u0430\u043A\u0430 \u0431\u043B\u043E\u043A\u0438\u0440\u0443\u0435\u0442 \u043E\u0442\u043F\u0440\u0430\u0432\u043A\u0443 \u0443\u0432\u0435\u0434\u043E\u043C\u043B\u0435\u043D\u0438\u0439 \u043E \u043F\u0440\u043E\u0447\u0442\u0435\u043D\u0438\u0438 \u0438 \u043D\u0430\u0431\u043E\u0440\u0435 \u0442\u0435\u043A\u0441\u0442\u0430 \u043D\u0430 \u0441\u0435\u0440\u0432\u0435\u0440."_q));

	Ui::AddSkip(content);
	Ui::AddSubsectionTitle(
		content,
		rpl::single(u"\u0418\u043D\u0442\u0435\u0440\u0444\u0435\u0439\u0441 \u0438 \u0432\u043D\u0435\u0448\u043D\u0438\u0439 \u0432\u0438\u0434"_q));
	AddToggle(content, u"\u0421\u043A\u0440\u044B\u0442\u044C \u043F\u0430\u043D\u0435\u043B\u044C \u0438\u0441\u0442\u043E\u0440\u0438\u0439"_q, s.hideStoriesBar);
	AddToggle(content, u"\u0421\u043A\u0440\u044B\u0442\u044C \u0440\u0435\u043A\u043B\u0430\u043C\u0443 \u0432 \u043A\u0430\u043D\u0430\u043B\u0430\u0445"_q, s.hideSponsored);
	AddToggle(content, u"\u041A\u043E\u043C\u043F\u0430\u043A\u0442\u043D\u044B\u0439 \u0441\u043F\u0438\u0441\u043E\u043A \u0447\u0430\u0442\u043E\u0432"_q, s.compactDialogs);
	AddToggle(content, u"\u041F\u043E\u043A\u0430\u0437\u044B\u0432\u0430\u0442\u044C \u0441\u0435\u043A\u0443\u043D\u0434\u044B \u0432\u043E \u0432\u0440\u0435\u043C\u0435\u043D\u0438"_q, s.exactTimeSeconds);
	Ui::AddSkip(content);
	Ui::AddDivider(content);

	Ui::AddSkip(content);
	Ui::AddSubsectionTitle(
		content,
		rpl::single(u"\u0418\u043D\u0441\u0442\u0440\u0443\u043C\u0435\u043D\u0442\u044B \u0438 \u0443\u0434\u043E\u0431\u0441\u0442\u0432\u043E"_q));
	AddToggle(content, u"\u041F\u043E\u043A\u0430\u0437\u044B\u0432\u0430\u0442\u044C ID \u0432 \u043F\u0440\u043E\u0444\u0438\u043B\u044F\u0445 \u0438 \u0447\u0430\u0442\u0430\u0445"_q, s.showPeerId);
	AddToggle(content, u"\u041F\u043E\u0434\u0442\u0432\u0435\u0440\u0436\u0434\u0435\u043D\u0438\u0435 \u043F\u0435\u0440\u0435\u0434 \u0437\u0432\u043E\u043D\u043A\u043E\u043C"_q, s.confirmCalls);
	Ui::AddSkip(content);
	Ui::AddDivider(content);

	Ui::AddSkip(content);
	const auto resetBtn = content->add(
		object_ptr<Ui::SettingsButton>(
			content,
			rpl::single(u"\u0421\u0431\u0440\u043E\u0441\u0438\u0442\u044C \u043D\u0430\u0441\u0442\u0440\u043E\u0439\u043A\u0438 \u0424\u0423\u0412\u041B\u0418 \u041C\u041E\u0414"_q),
			st::settingsAttentionButton));
	resetBtn->addClickHandler([=] {
		Core::FuvliSettings::Instance().resetToDefaults();
		controller->showToast(u"\u041D\u0430\u0441\u0442\u0440\u043E\u0439\u043A\u0438 \u0424\u0423\u0412\u041B\u0418 \u041C\u041E\u0414 \u0441\u0431\u0440\u043E\u0448\u0435\u043D\u044B"_q);
	});
	Ui::AddSkip(content);

	Ui::ResizeFitChild(this, content);
}

} // namespace Settings
'@

Write-Utf8 "Telegram\SourceFiles\core\fuvli_settings.h" $fuvliSettingsH
Write-Utf8 "Telegram\SourceFiles\settings\settings_fuvli.h" $settingsFuvliH
Write-Utf8 "Telegram\SourceFiles\settings\settings_fuvli.cpp" $settingsFuvliCpp

# 4. Register files & API keys in Telegram/CMakeLists.txt
Patch-File "Telegram\CMakeLists.txt" {
	param($c)
	if ($c -notmatch 'settings/settings_fuvli\.cpp') {
		$c = $c -replace '(settings/sections/settings_main\.h)', "`$1`n    core/fuvli_settings.h`n    settings/settings_fuvli.cpp`n    settings/settings_fuvli.h"
	}
	$c = $c -replace 'TDESKTOP_API_ID=\$\{TDESKTOP_API_ID\}', 'TDESKTOP_API_ID=32689426'
	$c = $c -replace 'TDESKTOP_API_HASH=\$\{TDESKTOP_API_HASH\}', 'TDESKTOP_API_HASH=c73c0d9f6585d94c667132efd7ad94b4'
	return $c
}

# 5. Load config on startup in core/application.cpp
Patch-File "Telegram\SourceFiles\core\application.cpp" {
	param($c)
	if ($c -notmatch 'core/fuvli_settings\.h') {
		$c = $c -replace '(#include "core/core_settings\.h")', "`$1`n#include `"core/fuvli_settings.h`""
		$c = $c -replace '(Local::start\(\);)', "`$1`n`tCore::FuvliSettings::Instance().load(cWorkingDir() + u`"tdata/fuvli_mod.json`"_q);"
	}
	return $c
}

# 6. Add button in settings/sections/settings_main.cpp
Patch-File "Telegram\SourceFiles\settings\sections\settings_main.cpp" {
	param($c)
	if ($c -notmatch 'settings/settings_fuvli\.h') {
		$c = $c -replace '(#include "settings/sections/settings_advanced\.h")', "`$1`n#include `"settings/settings_fuvli.h`""
		$btn = @"
	builder.addSectionButton({
		.title = rpl::single(u"\u0424\u0423\u0412\u041B\u0418 \u041C\u041E\u0414"_q),
		.targetSection = Fuvli::Id(),
		.icon = { &st::menuIconCustomize },
		.keywords = { u"fuvli"_q, u"mod"_q, u"ghost"_q },
	});
"@
		$c = $c -replace '(targetSection = AdvancedId\(\),[\s\S]*?\}\);)', "`$1`n`n$btn"
	}
	return $c
}

# 7. Feature 1: Ghost Mode Read (data/data_histories.cpp)
Patch-File "Telegram\SourceFiles\data\data_histories.cpp" {
	param($c)
	if ($c -notmatch 'core/fuvli_settings\.h') {
		$c = $c -replace '(#include "data/data_histories\.h")', "`$1`n#include `"core/fuvli_settings.h`""
		$c = $c -replace '(void Histories::sendReadRequests\(\)\s*\{)', "`$1`n`tif (Core::FuvliSettings::Instance().ghostRead.current()) {`n`t`t_readRequests.clear();`n`t`treturn;`n`t}"
	}
	return $c
}

# 8. Feature 2: Hide Typing (api/api_send_progress.cpp)
Patch-File "Telegram\SourceFiles\api\api_send_progress.cpp" {
	param($c)
	if ($c -notmatch 'core/fuvli_settings\.h') {
		$c = $c -replace '(#include "api/api_send_progress\.h")', "`$1`n#include `"core/fuvli_settings.h`""
		$c = $c -replace '(void SendProgressManager::send\([^)]*\)\s*\{)', "`$1`n`tif (Core::FuvliSettings::Instance().hideTyping.current()) {`n`t`treturn;`n`t}"
	}
	return $c
}

# 9. Feature 3: Ghost Stories (data/data_stories.cpp)
Patch-File "Telegram\SourceFiles\data\data_stories.cpp" {
	param($c)
	if ($c -notmatch 'core/fuvli_settings\.h') {
		$c = $c -replace '(#include "data/data_stories\.h")', "`$1`n#include `"core/fuvli_settings.h`""
		$c = $c -replace '(void Stories::sendMarkAsReadRequests\(\)\s*\{)', "`$1`n`tif (Core::FuvliSettings::Instance().ghostStories.current()) {`n`t`t_markAsReadRequests.clear();`n`t`treturn;`n`t}"
		$c = $c -replace '(void Stories::sendIncrementViewsRequests\(\)\s*\{)', "`$1`n`tif (Core::FuvliSettings::Instance().ghostStories.current()) {`n`t`t_incrementViewsRequests.clear();`n`t`treturn;`n`t}"
	}
	return $c
}

# 10. Feature 4: Anti-Delete Messages (data/data_session.cpp)
Patch-File "Telegram\SourceFiles\data\data_session.cpp" {
	param($c)
	if ($c -notmatch 'core/fuvli_settings\.h') {
		$c = $c -replace '(#include "data/data_session\.h")', "`$1`n#include `"core/fuvli_settings.h`""
		$c = $c -replace '(void Session::processMessagesDeleted\([^)]*\)\s*\{)', "`$1`n`tif (Core::FuvliSettings::Instance().antiDelete.current()) {`n`t`treturn;`n`t}"
		$c = $c -replace '(void Session::processNonChannelMessagesDeleted\([^)]*\)\s*\{)', "`$1`n`tif (Core::FuvliSettings::Instance().antiDelete.current()) {`n`t`treturn;`n`t}"
	}
	return $c
}

# 11. Feature 5: Hide Stories Bar (dialogs/dialogs_widget.cpp)
Patch-File "Telegram\SourceFiles\dialogs\dialogs_widget.cpp" {
	param($c)
	if ($c -notmatch 'core/fuvli_settings\.h') {
		$c = $c -replace '(#include "dialogs/dialogs_widget\.h")', "`$1`n#include `"core/fuvli_settings.h`""
		$c = $c -replace '(void Widget::setupStories\(\)\s*\{)', "`$1`n`tif (Core::FuvliSettings::Instance().hideStoriesBar.current()) {`n`t`treturn;`n`t}"
	}
	return $c
}

# 12. Feature 6: Hide Sponsored Messages (data/components/sponsored_messages.cpp)
Patch-File "Telegram\SourceFiles\data\components\sponsored_messages.cpp" {
	param($c)
	if ($c -notmatch 'core/fuvli_settings\.h') {
		$c = $c -replace '(#include "data/components/sponsored_messages\.h")', "`$1`n#include `"core/fuvli_settings.h`""
		$c = $c -replace '(bool SponsoredMessages::canHaveFor\([^)]*\)\s*const\s*\{)', "`$1`n`tif (Core::FuvliSettings::Instance().hideSponsored.current()) {`n`t`treturn false;`n`t}"
	}
	return $c
}

# 13. Feature 7: Compact Dialogs (dialogs/dialogs_row.cpp)
Patch-File "Telegram\SourceFiles\dialogs\dialogs_row.cpp" {
	param($c)
	if ($c -notmatch 'core/fuvli_settings\.h') {
		$c = $c -replace '(#include "dialogs/dialogs_row\.h")', "`$1`n#include `"core/fuvli_settings.h`""
		$c = $c -replace '(int BasicRow::height\(\)\s*const\s*\{)', "`$1`n`tif (Core::FuvliSettings::Instance().compactDialogs.current() && _height > 48) {`n`t`treturn 48;`n`t}"
	}
	return $c
}

# 14. Feature 8: Exact Time with Seconds (history/view/history_view_bottom_info.cpp)
Patch-File "Telegram\SourceFiles\history\view\history_view_bottom_info.cpp" {
	param($c)
	if ($c -notmatch 'core/fuvli_settings\.h') {
		$c = $c -replace '(#include "history/view/history_view_bottom_info\.h")', "`$1`n#include `"core/fuvli_settings.h`""
		$c = $c -replace 'QLocale\(\)\.toString\(([^,]+),\s*QLocale::ShortFormat\)', '(Core::FuvliSettings::Instance().exactTimeSeconds.current() ? QLocale().toString($1, u"HH:mm:ss"_q) : QLocale().toString($1, QLocale::ShortFormat))'
	}
	return $c
}

# 15. Feature 9: Show Peer ID in Profile (info/profile/info_profile_values.cpp)
Patch-File "Telegram\SourceFiles\info\profile\info_profile_values.cpp" {
	param($c)
	if ($c -notmatch 'core/fuvli_settings\.h') {
		$c = $c -replace '(#include "info/profile/info_profile_values\.h")', "`$1`n#include `"core/fuvli_settings.h`""
		$c = $c -replace 'rpl::producer<TextWithEntities> AboutValue\(not_null<PeerData\*> peer\)\s*\{', "rpl::producer<TextWithEntities> AboutValue(not_null<PeerData*> peer);`n`nrpl::producer<TextWithEntities> AboutValueFuvliBase(not_null<PeerData*> peer) {"
		$wrapper = @'
rpl::producer<TextWithEntities> AboutValue(not_null<PeerData*> peer) {
	const auto id = peer->id.value;
	return AboutValueFuvliBase(peer) | rpl::map([id](TextWithEntities text) {
		if (Core::FuvliSettings::Instance().showPeerId.current()) {
			if (!text.text.isEmpty()) {
				text.append(u"\n"_q);
			}
			text.append(u"ID: "_q + QString::number(id));
		}
		return text;
	});
}

} // namespace Info::Profile
'@
		$c = $c -replace '\}\s*//\s*namespace Info::Profile', $wrapper
	}
	return $c
}

# 16. Feature 10: Confirm Outgoing Calls (calls/calls_instance.h & calls_instance.cpp)
Patch-File "Telegram\SourceFiles\calls\calls_instance.h" {
	param($c)
	if ($c -notmatch 'startOutgoingCallConfirmed') {
		$c = $c -replace '(void startOutgoingCall\()', "void startOutgoingCallConfirmed(not_null<UserData*> user, StartOutgoingCallArgs args);`n`t`$1"
	}
	return $c
}

Patch-File "Telegram\SourceFiles\calls\calls_instance.cpp" {
	param($c)
	if ($c -notmatch 'core/fuvli_settings\.h') {
		$c = $c -replace '(#include "calls/calls_instance\.h")', "`$1`n#include `"core/fuvli_settings.h`"`n#include `"ui/boxes/confirm_box.h`"`n#include `"window/window_controller.h`""
		$confirmHook = @'
void Instance::startOutgoingCall(
		not_null<UserData*> user,
		StartOutgoingCallArgs args) {
	static bool ConfirmedOnce = false;
	if (!Core::FuvliSettings::Instance().confirmCalls.current() || ConfirmedOnce) {
		ConfirmedOnce = false;
		startOutgoingCallConfirmed(user, args);
		return;
	}
	if (const auto window = Core::App().activeWindow()) {
		window->show(Ui::MakeConfirmBox({
			.text = rpl::single(u"\u041F\u043E\u0437\u0432\u043E\u043D\u0438\u0442\u044C \u043F\u043E\u043B\u044C\u0437\u043E\u0432\u0430\u0442\u0435\u043B\u044E "_q + user->name() + u"?"_q),
			.confirmed = [=](Fn<void()> close) {
				close();
				ConfirmedOnce = true;
				startOutgoingCall(user, args);
			},
			.confirmText = rpl::single(u"\u041F\u043E\u0437\u0432\u043E\u043D\u0438\u0442\u044C"_q),
		}));
		return;
	}
	startOutgoingCallConfirmed(user, args);
}

void Instance::startOutgoingCallConfirmed(
'@
		$c = $c -replace 'void Instance::startOutgoingCall\(', $confirmHook
	}
	return $c
}

# 17. Inject API_ID & API_HASH into .github/workflows/win.yml
Patch-File ".github\workflows\win.yml" {
	param($c)
	$c = $c -replace '-DTDESKTOP_API_TEST=ON', '-DTDESKTOP_API_ID=32689426 -DTDESKTOP_API_HASH=c73c0d9f6585d94c667132efd7ad94b4'
	$c = $c -replace '\$\{\{\s*secrets\.API_ID\s*\}\}', '32689426'
	$c = $c -replace '\$\{\{\s*secrets\.API_HASH\s*\}\}', 'c73c0d9f6585d94c667132efd7ad94b4'
	return $c
}

Write-Host "`nFUVLI MOD SUCCESSFULLY INSTALLED!" -ForegroundColor Green
Start-Sleep -Seconds 4