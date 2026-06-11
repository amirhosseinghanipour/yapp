enum ChatListKind { dm, saved }

ChatListKind chatListKindFromGraphQL(String? raw) {
  switch (raw) {
    case 'saved':
      return ChatListKind.saved;
    case 'dm':
    default:
      return ChatListKind.dm;
  }
}
