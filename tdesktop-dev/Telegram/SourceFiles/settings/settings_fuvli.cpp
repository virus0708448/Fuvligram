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