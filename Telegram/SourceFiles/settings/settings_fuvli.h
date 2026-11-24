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