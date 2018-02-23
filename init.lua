box.cfg{listen=3324}
box.space.file:drop()
box.sequence.S:drop()
box.schema.space.create('file',{id=24})
box.schema.sequence.create('S',{min=1, start=1})
box.space.file:create_index('I',{sequence='S'})
--box.space.file:create_index('primary', {type = 'TREE', parts = {1, 'unsigned'}})
--box.schema.user.grant('guest', 'read,write,execute', 'universe')
