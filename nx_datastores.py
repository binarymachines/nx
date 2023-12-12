#!/usr/bin/env python

import json
from snap import common
from mercury.dataload import DataStore
from mercury.mlog import mlog, mlog_err
import uuid
from collections import namedtuple


class ObjectFactory(object):
    @classmethod
    def create_db_object(cls, table_name, db_svc, **kwargs):
        DbObject = getattr(db_svc.Base.classes, table_name)
        return DbObject(**kwargs)


class MongoDatastore(DataStore):
    def __init__(self, service_object_registry, *channels, **kwargs):
        super().__init__(service_object_registry, *channels, **kwargs)


    def write_reddit_doc(self, record, mongo_db_svc):
        print('writing Mongo record...')

        db = mongo_db_svc.get_database()
        collection = db['reddit_posts']
        id = collection.insert_one(record).inserted_id
        return str(id)


    def write(self, records, **write_params):

        mongo_svc = self.service_object_registry.lookup('mongo')
        
        for raw_rec in records:
            rec = json.loads(raw_rec)
            try:
                output_record = rec['data']
                newid =  self.write_reddit_doc(output_record, mongo_svc)
                
                output_record['mongo_id'] = newid
                print(output_record)

            except Exception as err:
                mlog_err(
                    err, issue=f"Error ingesting Mongo document.", record=rec
                )


ValueBin = namedtuple('ValueBin', 'min max name')

class PostgresDatastore(DataStore):
    def __init__(self, service_object_registry, *channels, **kwargs):
        super().__init__(service_object_registry, *channels, **kwargs)

        self.bins = []
        self.bins.append(ValueBin(min=0, max=9, name='0-10'))
        self.bins.append(ValueBin(min=10, max=49, name='10-49'))
        self.bins.append(ValueBin(min=50, max=99, name='50-99'))
        self.bins.append(ValueBin(min=100, max=999, name='100-999'))
        self.bins.append(ValueBin(min=1000, max=None, name='>1000'))

        
    def binned_value(self, value):

        for bin in self.bins:
            if value >= bin.min:
                if bin.max is None:
                    return bin.name
                elif value <= bin.max:
                    return bin.name


    def prepare_binned_values(self, record, *src_keys):

        upvote_count = record['num_upvotes']

        bvalues = {
            'dim_upvotes_bin_name': self.binned_value(record['num_upvotes']),
            'dim_comments_bin_name': self.binned_value(record['num_comments']),
            'dim_crossposts_bin_name': self.binned_value(record['num_crossposts'])
        }

        return bvalues
    

    def write_reddit_data(self, record, db_service, **write_params):
        output_rec = record

        with db_service.txn_scope() as session:  
            post_data = {
                'id': str(uuid.uuid4()),
                'mdb_object_id': 'mongo_id_placeholder',
                'reddit_id': record['id'],
                'subreddit_id': record['subreddit_id'],
                'subreddit_name': record['subreddit'],
                'author_name': record['author'],
                'num_upvotes': record['ups'],
                'num_comments': record['num_comments'],
                'num_crossposts': record['num_crossposts'],
                'score': record['score'],
                'event_timestamp': record['created_utc']
            }

            binned_value_names = self.prepare_binned_values(post_data)


            """
            new_post = ObjectFactory.create_db_object(
                "fact_post", db_service, **post_data
            )

            # TODO: skip subsequent steps in case of exception
            session.add(new_post)
            """
            return post_data


    def write(self, records, **write_params):
        postgres_svc = self.service_object_registry.lookup("postgres")
        record_type = write_params.get("record_type", "NULL")
        for raw_rec in records:
            rec = json.loads(raw_rec)
            if record_type == "reddit_post":
                try:
                    output_rec = self.write_reddit_data(rec, postgres_svc)
                    print(json.dumps(output_rec))

                except Exception as err:
                    mlog_err(
                        err, issue=f"Error ingesting {record_type} record.", record=rec
                    )

            else:
                mlog_err(
                    Exception(
                        f"Unrecognized or unspecified record type {record_type}. Please check your ngst command parameters."
                    )
                )
