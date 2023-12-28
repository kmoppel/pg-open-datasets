import re

r_posts = r'^.*<row Id="(.*)" PostTypeId="(.*)" AcceptedAnswerId="(.*)" CreationDate="(.*)" Score="(.*)" ViewCount="(.*)" Body="(.*)" OwnerUserId="(.*)" LastEditorUserId="(.*)" LastEditDate="(.*)" LastActivityDate="(.*)" Title="(.*)" Tags="(.*)" AnswerCount="(.*)" CommentCount="(.*)" ContentLicense="(.*)" />'
r_post_history = r'^.*<row Id="(.*)" PostHistoryTypeId="(.*)" PostId="(.*)" RevisionGUID="(.*)" CreationDate="(.*)" UserId="(.*)" Text="(.*)" ContentLicense="(.*)" />'
