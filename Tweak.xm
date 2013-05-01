#import "HBTypeStatusMac.h"
#import <IMFoundation/FZMessage.h>

%config(generator=internal);

int typingIndicators = 0;

%hook IMChatRegistry
-(void)account:(id)account chat:(id)chat style:(unsigned char)style chatProperties:(id)properties messageReceived:(FZMessage *)message {
	%orig;

	if (message.flags == 4104) {
		typingIndicators++;

		[[HBTypeStatusMac sharedInstance] setIconVisible:YES withName:message.handle];
	} else {
		typingIndicators--;

		if (typingIndicators < 0) {
			typingIndicators = 0;
		}

		if (typingIndicators == 0) {
			[[HBTypeStatusMac sharedInstance] setIconVisible:NO withName:nil];
		}
	}
}
%end
